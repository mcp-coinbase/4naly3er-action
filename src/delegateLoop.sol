contract DelegateCaller {
    address public libraryAddress; // Address of the library contract

    constructor(address _libraryAddress) {
        libraryAddress = _libraryAddress;
    }

    // Function to perform delegatecall inside a loop
    function delegateInLoop(address[] calldata targets, bytes calldata data) external {
        for (uint i = 0; i < targets.length; i++) {
            (bool success, ) = targets[i].delegatecall(abi.encodePacked(data));
            require(success, "Delegatecall failed");
        }
    }
}
