// SPDX-License-Identifier: NONE
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // security for non-reentrant
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
interface MutationPointsGetter{ 
function NFTMutationPoints(uint tokenId ) external returns (uint RD, uint GR, uint BK, uint BU, uint WH, uint OR, uint PR);
}

contract MutationPointsFarming is ReentrancyGuard,AccessControl {
 MutationPointsGetter SUPAVirus= MutationPointsGetter(0xe2a9b15E283456894246499Fb912CCe717f83319); //SUPACell clone contract address
  MutationPointsGetter SUPACell= MutationPointsGetter(0xe2a9b15E283456894246499Fb912CCe717f83319); //SUPAVirus clone contract address

uint multiplier=10000;
struct MutationPoints {
    uint RD;
    uint GR;
    uint BK;
    uint BU;
    uint WH;
    uint OR;
    uint PR;
    uint lastFarmed;
    }
    using ECDSA for bytes32;
      bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");
address payable contractOwner; 
mapping(address => MutationPoints) private playerMutationPoints;
mapping(string => bool) public txnDone;
bool public isPaused=false;
 constructor() {
        contractOwner = payable(msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(SIGN_ROLE, 0x59D3445a426C3CB6CeBC3033073F5d8ED5BE9fDd);
    }

     
      
      function verifyMPSig(int RD, int GR, int BK, int BU, int WH, int OR, int PR, address playerAddress, string memory uuid, bytes memory sig) internal virtual returns (bool) {
          bytes memory mutations=abi.encodePacked(int2str(RD),int2str(GR),int2str(BK),int2str(BU),int2str(WH),int2str(OR),int2str(PR));
          bytes memory toByte=bytes(abi.encodePacked(playerAddress,uuid,mutations));
       return hasRole(SIGN_ROLE, keccak256(toByte)
        .toEthSignedMessageHash()
        .recover(sig));
    }
    function setPause(bool toPause) public onlyRole(DEFAULT_ADMIN_ROLE){
            isPaused = toPause;

    }
    function setMultiplier(uint newMultiplier) public onlyRole(DEFAULT_ADMIN_ROLE){
            multiplier = newMultiplier;

    }

    function update(int RDnew, int GRnew, int BKnew, int BUnew, int WHnew, int ORnew, int PRnew, address playerAddress, string memory uuid, bytes memory sig) public  nonReentrant{
           require(
           isPaused==false ,
            "Updating is Paused."
        );

          require(verifyMPSig(RDnew,GRnew, BKnew, BUnew, WHnew, ORnew, PRnew,playerAddress,uuid,sig),"Invalid signature provided"); 
         require(txnDone[uuid]==false,"Already claimed");
         require( int(playerMutationPoints[playerAddress].RD)+ RDnew>0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].GR)+ GRnew>0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].BK)+ BKnew>0,"Insufficient balance");  
         require( int(playerMutationPoints[playerAddress].BU)+ BUnew>0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].WH)+ WHnew>0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].OR)+ ORnew>0,"Insufficient balance");  
        require( int(playerMutationPoints[playerAddress].PR)+ PRnew>0,"Insufficient balance");
       playerMutationPoints[playerAddress].RD= uint(int(playerMutationPoints[playerAddress].RD)+RDnew);
        playerMutationPoints[playerAddress].GR= uint(int(playerMutationPoints[playerAddress].RD)+GRnew);
        playerMutationPoints[playerAddress].BK= uint(int(playerMutationPoints[playerAddress].RD)+BKnew);
        playerMutationPoints[playerAddress].BU= uint(int(playerMutationPoints[playerAddress].RD)+BUnew);
         playerMutationPoints[playerAddress].WH= uint(int(playerMutationPoints[playerAddress].RD)+WHnew);
         playerMutationPoints[playerAddress].OR= uint(int(playerMutationPoints[playerAddress].RD)+ORnew);
         playerMutationPoints[playerAddress].PR= uint(int(playerMutationPoints[playerAddress].RD)+PRnew);
            txnDone[uuid]=true;
        
     }


    function farm(uint tokenId, uint organism ) public  nonReentrant{
         require(
           isPaused==false ,
            "Farming is Paused."
        );

        require(block.timestamp>playerMutationPoints[msg.sender].lastFarmed+86400,"Not ready yet");
        require(organism==1||organism==0,"invalidOrganism");
        if(organism==0){
                //SUPAVirus
        (uint RDnew, uint GRnew, uint BKnew, uint BUnew, uint WHnew, uint ORnew, uint PRnew) =  SUPAVirus.NFTMutationPoints(tokenId);
        playerMutationPoints[msg.sender].RD+= RDnew*multiplier;
        playerMutationPoints[msg.sender].GR+= GRnew*multiplier;
        playerMutationPoints[msg.sender].BK+= BKnew*multiplier;
        playerMutationPoints[msg.sender].BU+= BUnew*multiplier;
        playerMutationPoints[msg.sender].WH+= WHnew*multiplier;
        playerMutationPoints[msg.sender].OR+= ORnew*multiplier;
        playerMutationPoints[msg.sender].PR+= PRnew*multiplier;
        playerMutationPoints[msg.sender].lastFarmed=block.timestamp;
                } else{
         (uint RDnew, uint GRnew, uint BKnew, uint BUnew, uint WHnew, uint ORnew, uint PRnew) =  SUPACell.NFTMutationPoints(tokenId);
        playerMutationPoints[msg.sender].RD+= RDnew*multiplier;
        playerMutationPoints[msg.sender].GR+= GRnew*multiplier;
        playerMutationPoints[msg.sender].BK+= BKnew*multiplier;
        playerMutationPoints[msg.sender].BU+= BUnew*multiplier;
        playerMutationPoints[msg.sender].WH+= WHnew*multiplier;
        playerMutationPoints[msg.sender].OR+= ORnew*multiplier;
        playerMutationPoints[msg.sender].PR+= PRnew*multiplier;
        playerMutationPoints[msg.sender].lastFarmed=block.timestamp;
                }
   
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

function int2str(int i) internal pure returns (string memory _uintAsString){
    if (i == 0) return "0";
    bool negative = i < 0;
    uint j = uint(negative ? -i : i);
    uint l = j;     // Keep an unsigned copy
    uint len;
    while (j != 0){
        len++;
        j /= 10;
    }
    if (negative) ++len;  // Make room for '-' sign
    bytes memory bstr = new bytes(len);
    uint k = len;
    while (l != 0){
       k = k-1;
       uint8 temp = (48 + uint8(l % 10));    
        bstr[k] = bytes1(temp);
        l /= 10;
    }
    if (negative) {    // Prepend '-'
        bstr[0] = '-';
    }
    return string(bstr);
}
}