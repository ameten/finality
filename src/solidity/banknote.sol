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

contract Killable {
    function kill() public returns (bool success);
}

contract Mortal is Owned {

    function kill() onlyowner public returns (bool success) {
        suicide(owner);
        return true;
    }
}

contract Minter is Mortal {

    uint256 private supply;

    function mint(uint256 amount) internal returns (bool success) {

        uint256 temp = supply + amount;
        if (temp < supply) {
            return false;
        }

        supply = temp;
        return true;
    }

    function unmint(uint256 amount) internal returns (bool success) {
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

contract Banknote is Killable {

    address public issuer;
    address private holder;

    uint256 public faceValue;

    function Banknote(address _issuer, uint256 _faceValue) {
        issuer = _issuer;
        faceValue = _faceValue;
        holder = _issuer;
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
        if (holder == issuer) {
            CentralBank centralBank = CentralBank(issuer);
            centralBank.destroy(this);
        }
    }

    function change(uint256[] _faceValues) public returns (address[]) {

        /*
            Prevent change banknotes which don't belong to transaction sender.
        */
        if (msg.sender != holder) {
            address[] unchanged;
            unchanged.length = 1;
            unchanged[0] = this;
            return unchanged;
        }

        holder = issuer;

        CentralBank centralBank = CentralBank(issuer);
        centralBank.change(this, _faceValues);
    }

    function mine() public returns (bool yes) {
        return holder == msg.sender;
    }

    function returned() public returns (bool yes) {
        return issuer == holder;
    }

    function kill() public returns (bool) {
        if (!returned()) {
            return false;
        }

        suicide(issuer);
        return true;
    }
}

contract CentralBank is Minter {

    /*
        Keeps all minted banknotes and their face values.
    */
    mapping (address => uint256) banknotes;

    function print(uint256 _faceValue) private returns (address _banknote) {

        if (!super.mint(_faceValue)) {
            return 0;
        }

        Banknote banknote = new Banknote(this, _faceValue);
        banknotes[banknote] = _faceValue;
        return banknote;
    }

    function destroy(address _banknote) public returns (bool success) {

        if (!genuine(_banknote)) {
            return false;
        }

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

    function destroy(address[] _banknotes) public returns (bool success) {
        for (uint256 i = 0; i < _banknotes.length; ++i) {
            address banknote = _banknotes[i];

            if (banknote != 0) {
                destroy(banknote);
            }
        }
    }

    function genuine(address _banknote) public returns (bool yes) {
        return banknotes[_banknote] != 0;
    }

    function issue(uint256 _faceValue, address _holder) onlyowner public returns (address _banknote) {
        address fresh = print(_faceValue);

        if (fresh == 0) {
            return 0;
        }

        Banknote banknote = Banknote(fresh);
        banknote.transfer(_holder);
        return banknote;
    }

    function change(address _banknote, uint256[] _faceValues) public returns (address[]) {

        if (!genuine(_banknote)) {
            return unchanged(_banknote);
        }

        Banknote banknote = Banknote(_banknote);
        uint256 faceValue = banknote.faceValue();

        /*
            Only banknote holder can ask for change.
        */
        if (!banknote.mine()) {
            return unchanged(_banknote);
        }

        // assert msg.sender == banknote.holder.

        uint256 length = _faceValues.length;

        uint256 sum = 0;
        for (uint256 i = 0; i < length; ++i) {
            sum += _faceValues[i];
        }

        if (sum > faceValue) {
            return unchanged(_banknote);
        }

        uint256 reminder = faceValue - sum;

        if (!destroy(_banknote)) {
            banknote.transfer(msg.sender);
            return unchanged(_banknote);
        }

        address[] banknotes;

        if (reminder == 0) {
            banknotes.length = _faceValues.length;
        } else {
            banknotes.length = _faceValues.length + 1;
        }

        for (uint256 j = 0; j < length; ++j) {
            address hot = print(_faceValues[j]);

            if (hot == 0) {
                destroy(banknotes);
                banknote.transfer(msg.sender);
                return unchanged(_banknote);
            }

            banknotes[j] = hot;
        }

        if (reminder != 0) {
            address hotter = print(reminder);

            if (hotter == 0) {
                destroy(banknotes);
                banknote.transfer(msg.sender);
                return unchanged(_banknote);
            }

            banknotes[_faceValues.length] = hotter;
        }

        return banknotes;
    }

    function unchanged(address _banknote) private returns (address[] _unchanged) {
        address[] unchanged;
        unchanged.length = 1;
        unchanged[0] = _banknote;
        return unchanged;
    }
}

contract Exchange is Mortal {

}