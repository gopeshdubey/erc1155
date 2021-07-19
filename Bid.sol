// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./BidStorage.sol";


contract Bid is Ownable, Pausable, BidStorage {
    using SafeMath for uint256;
    using Address for address;

    constructor(address _nftToken, address _owner) Ownable() Pausable() {
        manaToken = ERC1155(_nftToken);
        // Set owner
        transferOwnership(_owner);
    }

    function placeBid(
        address _tokenAddress, 
        uint256 _tokenId,
        uint256 _price,
        uint256 _duration
    )
        public
    {
        _placeBid(
            _tokenAddress, 
            _tokenId,
            _price,
            _duration,
            ""
        );
    }

    function placeBid(
        address _tokenAddress, 
        uint256 _tokenId,
        uint256 _price,
        uint256 _duration,
        bytes memory _fingerprint
    )
        public
    {
        _placeBid(
            _tokenAddress, 
            _tokenId,
            _price,
            _duration,
            _fingerprint 
        );
    }

    function _placeBid(
        address _tokenAddress, 
        uint256 _tokenId,
        uint256 _price,
        uint256 _duration,
        bytes memory _fingerprint
    )
        private
        whenNotPaused()
    {
        _requireERC721(_tokenAddress);
        _requireComposableERC721(_tokenAddress, _tokenId, _fingerprint);

        require(_price > 0, "Price should be bigger than 0");

        _requireBidderBalance(msg.sender, _price);       

        require(
            _duration >= MIN_BID_DURATION, 
            "The bid should be last longer than a minute"
        );

        require(
            _duration <= MAX_BID_DURATION, 
            "The bid can not last longer than 6 months"
        );

        ERC1155 token = ERC1155(_tokenAddress);
        address tokenOwner = token.ownerOf(_tokenId);
        require(
            tokenOwner != address(0) && tokenOwner != msg.sender,
            "The token should have an owner different from the sender"
        );

        uint256 expiresAt = block.timestamp.add(_duration);

        bytes32 bidId = keccak256(
            abi.encodePacked(
                block.timestamp,
                msg.sender,
                _tokenAddress,
                _tokenId,
                _price,
                _duration,
                _fingerprint
            )
        );

        uint256 bidIndex;

        if (_bidderHasABid(_tokenAddress, _tokenId, msg.sender)) {
            bytes32 oldBidId;
            (bidIndex, oldBidId,,,) = getBidByBidder(_tokenAddress, _tokenId, msg.sender);
            
            // Delete old bid reference
            delete bidIndexByBidId[oldBidId];
        } else {
            // Use the bid counter to assign the index if there is not an active bid. 
            bidIndex = bidCounterByToken[_tokenAddress][_tokenId];  
            // Increase bid counter 
            bidCounterByToken[_tokenAddress][_tokenId]++;
        }

        // Set bid references
        bidIdByTokenAndBidder[_tokenAddress][_tokenId][msg.sender] = bidId;
        bidIndexByBidId[bidId] = bidIndex;

        // Save Bid
        bidsByToken[_tokenAddress][_tokenId][bidIndex] = Bid({
            id: bidId,
            bidder: msg.sender,
            tokenAddress: _tokenAddress,
            tokenId: _tokenId,
            price: _price,
            expiresAt: expiresAt,
            fingerprint: _fingerprint
        });

        emit BidCreated(
            bidId,
            _tokenAddress,
            _tokenId,
            msg.sender,
            _price,
            expiresAt,
            _fingerprint     
        );
    }

    function onERC721Received(
        address _from,
        address /*_to*/,
        uint256 _tokenId,
        bytes memory _data
    )
        public
        whenNotPaused()
        returns (bytes4)
    {
        bytes32 bidId = _bytesToBytes32(_data);
        uint256 bidIndex = bidIndexByBidId[bidId];

        Bid memory bid = _getBid(msg.sender, _tokenId, bidIndex);

        // Check if the bid is valid.
        require(
            // solium-disable-next-line operator-whitespace
            bid.id == bidId &&
            bid.expiresAt >= block.timestamp, 
            "Invalid bid"
        );

        address bidder = bid.bidder;
        uint256 price = bid.price;
        
        // Check fingerprint if necessary
        _requireComposableERC721(msg.sender, _tokenId, bid.fingerprint);

        // Check if bidder has funds
        _requireBidderBalance(bidder, price);

        // Delete bid references from contract storage
        delete bidsByToken[msg.sender][_tokenId][bidIndex];
        delete bidIndexByBidId[bidId];
        delete bidIdByTokenAndBidder[msg.sender][_tokenId][bidder];

        // Reset bid counter to invalidate other bids placed for the token
        delete bidCounterByToken[msg.sender][_tokenId];
        
        // Transfer token to bidder
        ERC1155(msg.sender).safeTransferFrom(address(this), bidder, _tokenId, 1,  "");

        uint256 saleShareAmount = 0;
        if (ownerCutPerMillion > 0) {
            // Calculate sale share
            saleShareAmount = price.mul(ownerCutPerMillion).div(ONE_MILLION);
            // Transfer share amount to the bid conctract Owner
            manaToken.safeTransferFrom(bidder, owner(), saleShareAmount, 1, "");
        }

        // Transfer MANA from bidder to seller
        manaToken.safeTransferFrom(bidder, _from, price.sub(saleShareAmount), 1, "");
       
        emit BidAccepted(
            bidId,
            msg.sender,
            _tokenId,
            bidder,
            _from,
            price,
            saleShareAmount
        );

        return ERC721_Received;
    }

    function removeExpiredBids(address[] memory _tokenAddresses, uint256[] memory _tokenIds, address[] memory _bidders)
    public 
    {
        uint256 loopLength = _tokenAddresses.length;

        require(loopLength == _tokenIds.length, "Parameter arrays should have the same length");
        require(loopLength == _bidders.length, "Parameter arrays should have the same length");

        for (uint256 i = 0; i < loopLength; i++) {
            _removeExpiredBid(_tokenAddresses[i], _tokenIds[i], _bidders[i]);
        }
    }
  
    function _removeExpiredBid(address _tokenAddress, uint256 _tokenId, address _bidder)
    internal 
    {
        (uint256 bidIndex, bytes32 bidId,,,uint256 expiresAt) = getBidByBidder(
            _tokenAddress, 
            _tokenId,
            _bidder
        );
        
        require(expiresAt < block.timestamp, "The bid to remove should be expired");

        _cancelBid(
            bidIndex, 
            bidId, 
            _tokenAddress, 
            _tokenId, 
            _bidder
        );
    }

    function cancelBid(address _tokenAddress, uint256 _tokenId) public whenNotPaused() {
        // Get active bid
        (uint256 bidIndex, bytes32 bidId,,,) = getBidByBidder(
            _tokenAddress, 
            _tokenId,
            msg.sender
        );

        _cancelBid(
            bidIndex, 
            bidId, 
            _tokenAddress, 
            _tokenId, 
            msg.sender
        );
    }

    function _cancelBid(
        uint256 _bidIndex,
        bytes32 _bidId, 
        address _tokenAddress,
        uint256 _tokenId, 
        address _bidder
    ) 
        internal 
    {
        // Delete bid references
        delete bidIndexByBidId[_bidId];
        delete bidIdByTokenAndBidder[_tokenAddress][_tokenId][_bidder];
        
        // Check if the bid is at the end of the mapping
        uint256 lastBidIndex = bidCounterByToken[_tokenAddress][_tokenId].sub(1);
        if (lastBidIndex != _bidIndex) {
            // Move last bid to the removed place
            Bid storage lastBid = bidsByToken[_tokenAddress][_tokenId][lastBidIndex];
            bidsByToken[_tokenAddress][_tokenId][_bidIndex] = lastBid;
            bidIndexByBidId[lastBid.id] = _bidIndex;
        }
        
        // Delete empty index
        delete bidsByToken[_tokenAddress][_tokenId][lastBidIndex];

        // Decrease bids counter
        bidCounterByToken[_tokenAddress][_tokenId]--;

        // emit BidCancelled event
        emit BidCancelled(
            _bidId,
            _tokenAddress,
            _tokenId,
            _bidder
        );
    }

    function _bidderHasABid(address _tokenAddress, uint256 _tokenId, address _bidder) 
        internal
        view 
        returns (bool)
    {
        bytes32 bidId = bidIdByTokenAndBidder[_tokenAddress][_tokenId][_bidder];
        uint256 bidIndex = bidIndexByBidId[bidId];
        // Bid index should be inside bounds
        if (bidIndex < bidCounterByToken[_tokenAddress][_tokenId]) {
            Bid memory bid = bidsByToken[_tokenAddress][_tokenId][bidIndex];
            return bid.bidder == _bidder;
        }
        return false;
    }

    function getBidByBidder(address _tokenAddress, uint256 _tokenId, address _bidder) 
        public
        view 
        returns (
            uint256 bidIndex, 
            bytes32 bidId, 
            address bidder, 
            uint256 price, 
            uint256 expiresAt
        ) 
    {
        bidId = bidIdByTokenAndBidder[_tokenAddress][_tokenId][_bidder];
        bidIndex = bidIndexByBidId[bidId];
        (bidId, bidder, price, expiresAt) = getBidByToken(_tokenAddress, _tokenId, bidIndex);
        if (_bidder != bidder) {
            revert("Bidder has not an active bid for this token");
        }
    }

    function getBidByToken(address _tokenAddress, uint256 _tokenId, uint256 _index) 
        public 
        view
        returns (bytes32, address, uint256, uint256) 
    {
        
        Bid memory bid = _getBid(_tokenAddress, _tokenId, _index);
        return (
            bid.id,
            bid.bidder,
            bid.price,
            bid.expiresAt
        );
    }

    function _getBid(address _tokenAddress, uint256 _tokenId, uint256 _index) 
        internal 
        view 
        returns (Bid memory)
    {
        require(_index < bidCounterByToken[_tokenAddress][_tokenId], "Invalid index");
        return bidsByToken[_tokenAddress][_tokenId][_index];
    }

    function setOwnerCutPerMillion(uint256 _ownerCutPerMillion) external onlyOwner {
        require(_ownerCutPerMillion < ONE_MILLION, "The owner cut should be between 0 and 999,999");

        ownerCutPerMillion = _ownerCutPerMillion;
        emit ChangedOwnerCutPerMillion(ownerCutPerMillion);
    }

    /**
    * @dev Convert bytes to bytes32
    * @param _data - bytes
    * @return bytes32
    */
    function _bytesToBytes32(bytes memory _data) internal pure returns (bytes32) {
        require(_data.length == 32, "The data should be 32 bytes length");

        bytes32 bidId;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            bidId := mload(add(_data, 0x20))
        }
        return bidId;
    }

    function _requireERC721(address _tokenAddress) internal view {
        require(_tokenAddress.isContract(), "Token should be a contract");

        ERC1155 token = ERC1155(_tokenAddress);
        require(
            token.supportsInterface(ERC721_Interface),
            "Token has an invalid ERC721 implementation"
        );
    }

    function _requireComposableERC721(
        address _tokenAddress,
        uint256 _tokenId,
        bytes memory _fingerprint
    )
        internal
        view
    {
        ERC721Verifiable composableToken = ERC721Verifiable(_tokenAddress);
        if (composableToken.supportsInterface(ERC721Composable_ValidateFingerprint)) {
            require(
                composableToken.verifyFingerprint(_tokenId, _fingerprint),
                "Token fingerprint is not valid"
            );
        }
    }

    function _requireBidderBalance(address _bidder, uint256 _id) internal view {
        require(
            manaToken.balanceOf(_bidder, _id) == _id,
            "Insufficient funds"
        );        
    }
}
