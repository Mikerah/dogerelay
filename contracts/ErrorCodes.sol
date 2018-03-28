pragma solidity ^0.4.19;

contract ErrorCodes {
  // Error codes

  uint constant ERR_SUPERBLOCK_OK = 0;
  uint constant ERR_SUPERBLOCK_EXIST = 50010;
  uint constant ERR_SUPERBLOCK_BAD_STATUS = 50020;
  uint constant ERR_SUPERBLOCK_TIMEOUT = 50030;
  uint constant ERR_SUPERBLOCK_INVALID_MERKLE = 50040;
  uint constant ERR_SUPERBLOCK_BAD_PARENT = 50050;
}
