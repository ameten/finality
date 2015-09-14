/*
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
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

    function kill() onlyowner public returns (bool success) {
        suicide(owner);
        return true;
    }
}

contract Minter is Mortal {

    uint256 private supply;

    function mint(uint256 amount) onlyowner public returns (bool success) {

        uint256 temp = supply + amount;
        if (temp < supply) {
            return false;
        }

        supply = temp;
        return true;
    }

    function unmint(uint256 amount) onlyowner public returns (bool success) {
        if (supply < amount) {
            return false;
        }

        supply -= amount;
        return true;
    }

    function kill() onlyowner public returns (bool success) {
        if (supply != 0) {
            return false;
        }

        return super.kill();
    }
}

/*
    Although banknote is mortal, it can be destroy only by issuer.
*/
contract Banknote is Mortal {

    uint256 public faceValue;
    address private holder;

    function Banknote(uint256 _faceValue) {
        faceValue = _faceValue;
        holder = msg.sender;
    }

    function transfer(address to) public returns (bool success) {
        /*
            Prevent transfer banknotes which don't belong to transaction sender.
        */
        if (msg.sender != holder) {
            return false;
        }

        holder = to;

        /*
            If banknote is returned to central bank, destroy it.
        */
        if (holder == owner) {
            CentralBank centralBank = CentralBank(owner);
            centralBank.destroy(this);
        }
    }

    function mine() public returns (bool yes) {
        return holder == msg.sender;
    }

    function issuer() public returns (address _address) {
        return owner;
    }

    function returned() public returns (bool yes) {
        return owner == holder;
    }
}

contract CentralBank is Minter {

    /*
        Keeps all minted banknotes and their face values.
    */
    mapping (address => uint256) banknotes;

    function print(uint256 _faceValue) onlyowner private returns (address _banknote) {

        if (!super.mint(_faceValue)) {
            return 0;
        }

        Banknote banknote = new Banknote(_faceValue);
        banknotes[banknote] = _faceValue;
        return banknote;
    }

    function destroy(address _banknote) public returns (bool success) {

        Banknote banknote = Banknote(_banknote);

        /*
            Central bank does not destroy a banknote or another contract which it did not issued.
        */
        if (owner != banknote.issuer()) {
            return false;
        }

        /*
            Central bank cannot destroy banknote which it does not hold.
        */
        if (!banknote.returned()) {
            return false;
        }

        banknotes[banknote] = 0;

        super.unmint(banknote.faceValue());

        banknote.kill();

        return true;
    }

    function issue(uint256 _faceValue, address _holder) onlyowner returns (address _banknote) {
        address fresh = print(_faceValue);

        if (fresh == 0) {
            return 0;
        }

        Banknote banknote = Banknote(fresh);
        banknote.transfer(_holder);
        return banknote;
    }
}