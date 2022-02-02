pragma solidity ^0.8.0;

contract Blocklist {
    string[] public hostlist;
    mapping(address => bool) public authorizedUsers;
    address public owner;

    constructor() {
        owner = msg.sender;
        authorizedUsers[msg.sender] = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "sender is not owner");
        _;
    }
    modifier onlyAuthorized() {
        require(authorizedUsers[msg.sender] == true, "not authorized");
        _;
    }

    function addHostName(string memory newValue) public onlyAuthorized {
        hostlist.push(newValue);
    }

    function getHostList() public view returns (string[] memory) {
        return hostlist;
    }

    function removeHostList(uint index) public onlyAuthorized {
        hostlist[index] = hostlist[hostlist.length - 1];
        hostlist.pop();
    }
    function authorizeUser(address userAddr) public onlyOwner {
        authorizedUsers[userAddr] = true;
    }

    function unAuthorizeUser(address userAddr) public {
        authorizedUsers[userAddr] = false;
    }

}