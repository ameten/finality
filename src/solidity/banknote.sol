contract Owned {

    address internal owner;

    function Owned() {
        owner = msg.sender;
    }

    modifier onlyowner {
        if (msg.sender == owner) _
    }
}

contract Mortal is Owned {

    function kill() onlyowner {
        suicide(owner);
    }
}