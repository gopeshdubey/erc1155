// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface ERC1155 {
    /**
        @dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).
        The `_operator` argument MUST be the address of an account/contract that is approved to make the transfer (SHOULD be msg.sender).
        The `_from` argument MUST be the address of the holder whose balance is decreased.
        The `_to` argument MUST be the address of the recipient whose balance is increased.
        The `_id` argument MUST be the token type being transferred.
        The `_value` argument MUST be the number of tokens the holder balance is decreased by and match what the recipient balance is increased by.
        When minting/creating tokens, the `_from` argument MUST be set to `0x0` (i.e. zero address).
        When burning/destroying tokens, the `_to` argument MUST be set to `0x0` (i.e. zero address).        
    */
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);

    /**
        @dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).      
        The `_operator` argument MUST be the address of an account/contract that is approved to make the transfer (SHOULD be msg.sender).
        The `_from` argument MUST be the address of the holder whose balance is decreased.
        The `_to` argument MUST be the address of the recipient whose balance is increased.
        The `_ids` argument MUST be the list of tokens being transferred.
        The `_values` argument MUST be the list of number of tokens (matching the list and order of tokens specified in _ids) the holder balance is decreased by and match what the recipient balance is increased by.
        When minting/creating tokens, the `_from` argument MUST be set to `0x0` (i.e. zero address).
        When burning/destroying tokens, the `_to` argument MUST be set to `0x0` (i.e. zero address).                
    */
    event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values);

    /**
        @dev MUST emit when approval for a second party/operator address to manage all tokens for an owner address is enabled or disabled (absence of an event assumes disabled).        
    */
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /**
        @dev MUST emit when the URI is updated for a token ID.
        URIs are defined in RFC 3986.
        The URI MUST point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
    */
    event URI(string _value, uint256 indexed _id);
    
    function ownerOf(uint256 _tokenId) external view returns (address _owner);
    
    function supportsInterface(bytes4) external view returns (bool);

    /**
        @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if balance of holder for token `_id` is lower than the `_value` sent.
        MUST revert on any other error.
        MUST emit the `TransferSingle` event to reflect the balance change (see "Safe Transfer Rules" section of the standard).
        After the above conditions are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call `onERC1155Received` on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).        
        @param _from    Source address
        @param _to      Target address
        @param _id      ID of the token type
        @param _value   Transfer amount
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
    */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;

    /**
        @notice Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if length of `_ids` is not the same as length of `_values`.
        MUST revert if any of the balance(s) of the holder(s) for token(s) in `_ids` is lower than the respective amount(s) in `_values` sent to the recipient.
        MUST revert on any other error.        
        MUST emit `TransferSingle` or `TransferBatch` event(s) such that all the balance changes are reflected (see "Safe Transfer Rules" section of the standard).
        Balance changes and events MUST follow the ordering of the arrays (_ids[0]/_values[0] before _ids[1]/_values[1], etc).
        After the above conditions for the transfer(s) in the batch are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call the relevant `ERC1155TokenReceiver` hook(s) on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).                      
        @param _from    Source address
        @param _to      Target address
        @param _ids     IDs of each token type (order and length must match _values array)
        @param _values  Transfer amounts per token type (order and length must match _ids array)
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
    */
    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external;

    /**
        @notice Get the balance of an account's tokens.
        @param _owner  The address of the token holder
        @param _id     ID of the token
        @return        The _owner's balance of the token type requested
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);

    /**
        @notice Get the balance of multiple account/token pairs
        @param _owners The addresses of the token holders
        @param _ids    ID of the tokens
        @return        The _owner's balance of the token types requested (i.e. balance for each (owner, id) pair)
     */
    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory);

    /**
        @notice Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
        @dev MUST emit the ApprovalForAll event on success.
        @param _operator  Address to add to the set of authorized operators
        @param _approved  True if the operator is approved, false to revoke approval
    */
    function setApprovalForAll(address _operator, bool _approved) external;

    /**
        @notice Queries the approval status of an operator for a given owner.
        @param _owner     The owner of the tokens
        @param _operator  Address of authorized operator
        @return           True if the operator is approved, false if not
    */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

/**
 * @title Interface for contracts conforming to ERC-20
 */
abstract contract ERC20Interface {
    function balanceOf(address from) virtual public view returns (uint256);
    function transferFrom(address from, address to, uint tokens) virtual public returns (bool);
    function allowance(address owner, address spender) virtual public view returns (uint256);
}


/**
 * @title Interface for contracts conforming to ERC-721
 */
abstract contract ERC721Interface {
    function ownerOf(uint256 _tokenId) virtual public view returns (address _owner);
    function transferFrom(address _from, address _to, uint256 _tokenId) virtual public;
    function supportsInterface(bytes4) virtual public view returns (bool);
}


abstract contract ERC721Verifiable is ERC721Interface {
    function verifyFingerprint(uint256, bytes memory) virtual public view returns (bool);
}


contract BidStorage {
    // 182 days - 26 weeks - 6 months
    uint256 public constant MAX_BID_DURATION = 182 days;
    uint256 public constant MIN_BID_DURATION = 1 minutes;
    uint256 public constant ONE_MILLION = 1000000;
    bytes4 public constant ERC721_Interface = 0x80ac58cd;
    bytes4 public constant ERC721_Received = 0x150b7a02;
    bytes4 public constant ERC721Composable_ValidateFingerprint = 0x8f9f4b63;
    
    struct Bid {
        // Bid Id
        bytes32 id;
        // Bidder address 
        address bidder;
        // ERC721 address
        address tokenAddress;
        // ERC721 token id
        uint256 tokenId;
        // Price for the bid in wei 
        uint256 price;
        // Time when this bid ends 
        uint256 expiresAt;
        // Fingerprint for composable
        bytes fingerprint;
    }

    // MANA token
    ERC1155 public manaToken;

    // Bid by token address => token id => bid index => bid
    mapping(address => mapping(uint256 => mapping(uint256 => Bid))) internal bidsByToken;
    // Bid count by token address => token id => bid counts
    mapping(address => mapping(uint256 => uint256)) public bidCounterByToken;
    // Index of the bid at bidsByToken mapping by bid id => bid index
    mapping(bytes32 => uint256) public bidIndexByBidId;
    // Bid id by token address => token id => bidder address => bidId
    mapping(address => mapping(uint256 => mapping(address => bytes32))) 
    public 
    bidIdByTokenAndBidder;


    uint256 public ownerCutPerMillion;

    // EVENTS
    event BidCreated(
      bytes32 _id,
      address indexed _tokenAddress,
      uint256 indexed _tokenId,
      address indexed _bidder,
      uint256 _price,
      uint256 _expiresAt,
      bytes _fingerprint
    );
    
    event BidAccepted(
      bytes32 _id,
      address indexed _tokenAddress,
      uint256 indexed _tokenId,
      address _bidder,
      address indexed _seller,
      uint256 _price,
      uint256 _fee
    );

    event BidCancelled(
      bytes32 _id,
      address indexed _tokenAddress,
      uint256 indexed _tokenId,
      address indexed _bidder
    );

    event ChangedOwnerCutPerMillion(uint256 _ownerCutPerMillion);
}
