// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract BuySell is ERC1155 {
    address public governance;
    uint256 public BuySellCount;
    
    modifier onlyGovernance() {
        require(msg.sender == governance, "only governance can call this");
        
        _;
    }

    constructor() ERC1155("") {}
    
    function BuySellNFT(address _from, address _to, uint256 _id, uint256 _amount) public {
        // _balances[_id][msg.sender] -= _amount;
        
        // balances[_id][address(this)] += _amount;
        
        safeTransferFrom(_from, _to, _id, _amount, "");
    }
    
    function MintBuySell(uint256 initialSupply) external onlyGovernance{
        BuySellCount++;
        uint256 BuySellClassId = BuySellCount;

        _mint(msg.sender, BuySellClassId, initialSupply, "");        
    }
}
