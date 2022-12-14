// SPDX-License-Identifier: GPL-3.0


pragma solidity >=0.7.0 <0.9.0;

/*
1 - An initial Coin Offering (ICO) is a type of crowdfunding using CCs.

2 - An ICO can be a source of capital for startup companies that offers investors some units of a new cc or crypto-token in exchange for a well-known
and valuable cc like ETH.

3 - The first ICO (also known as token-sale) was held by Mastercoin in July 2013. The ETH project raised money with a token-sale in 2014,
as well. It raised 3700 BTC in the first 12 hours.

4 - Who can launch an ICO? Literally anyone.

5 - Before launching an ICO, it's mandatory to verify and obey the laws of the countries your investors are coming from! For example, China
banned ICO's calling them illegal fundraising. Also note that the vast majority of ICO's have failed.

----------------------------------------------------- ICO TOKEN -------------------------------------------------------------

1 - Our ICO will be SC that accepts ETH in exchange for our own token named Cryptos (CRPT).

2 - Cryptos token is a fully compliant ERC20 token and will be generated at the ICO time.

3 - Investors will send ETH to the ICO contract's address and in return they will get amount of Cryptos.

4 - There will be a deposit address (EOA account) that automically receives ETH sent to the ICO contract.

5 - CRPT token price in wei is : 1CRPT = 0.001 ETH = 10 ** 15wei, 1ETH = 1000 CRPT.

6 - Min investment in 0.01 ETH and the max investment is 5 ETH.

7 - ICO hardcap is 300 ETH.

8 - ICO will have an admin that specifies when ICO starts and ends.

9 - ICO ends when the hardcap or the end time is reached (whichever comes first)

10 - CRPT token will be tradable only after a specific time set by the admin.

11 - In case of an emergency the admin could stop ICO and could also change the deposit address in case it gets compromised.

12 - The ICO can be in one of the following states : beforeStart, running, afterEnd, halted.

13 - We will also implement the possibility to burn the tokens that were not sold in ICO.

14 - After an investment in the ICO the Invest event will be emitted.

15 - Recommended approach is derive ICO from the token contract.

*/



interface ERC20Interface {
    function totalSupply() external view returns(uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function transfer(address to, uint tokens) external returns (bool success);

    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

}

contract Cryptos is ERC20Interface {
    string public name = "Cryptos";
    string public symbol = "CRPT";
    uint public decimals = 0; // 18
    uint public override totalSupply;

    address public founder;

    mapping (address => uint) public balances;
    mapping (address => mapping(address => uint)) public allowed;

    // 0x1111. (owner) allows 0x2222... (the spender) 0x12321 to spend 1000 token
    // allowed[0x1111][0x12321] = 1000;

    constructor() {
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function balanceOf(address tokenOwner) public view override returns (uint balance) {
        return balances[tokenOwner];
    }

    function transfer(address to, uint tokens) public virtual override returns(bool success) {  // virtual means the function can change its behavior
        require(balances[msg.sender] >= tokens);                                                // in derived contracts by overriding

        balances[to] += tokens;
        balances[msg.sender] -= tokens;

        emit Transfer(msg.sender, to, tokens);

        return true;
    }
    
    function allowance(address tokenOwner, address spender) public view override returns(uint) { // returns the amount spender still allowed to spent
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens) public override returns(bool success) {

        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);

        return true;

    }

    function transferFrom(address from, address to, uint tokens) public virtual override returns (bool success) {
        require(allowed[from][msg.sender] >= tokens);
        require(balances[from] >= tokens);

        balances[from] -= tokens;
        allowed[from][msg.sender] -= tokens; 
        balances[to] += tokens;

        emit Transfer(from, to, tokens);
        return true;
    }

}

contract CryptosICO is Cryptos {
    address public admin;
    address payable public deposit;
    uint tokenPrice = 0.001 ether; // 1 ETH = 1000 CRPT, 1CRPT = 0.001 ETH
    uint public hardCap = 300 ether;
    uint public raisedAmount;
    uint public saleStart = block.timestamp;        //
    uint public saleEnd = block.timestamp + 604800; // ico ends in 1 week
    uint public tokenTradeStart = saleEnd + 604800; // transferable in a week after saleEnd publish
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;

    enum State {beforeStart, running, afterEnd, halted}  // ICO States
    State public icoState;

    constructor (address payable _deposit) {
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    
    // In case of an emergency, for example if the deposit address get compromised or a security vulnerability is found in the contract.
     
    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    function halt() public onlyAdmin {
        icoState = State.halted;
    }

    function resume() public onlyAdmin {
        icoState = State.running;
    }

    function changeDepositAddress (address payable newDeposit) public onlyAdmin {
        deposit = newDeposit;
    }

    function getCurrentState() public view returns(State) {
        if(icoState == State.halted) {
            return State.halted;
        } else if (block.timestamp < saleStart) {
            return State.beforeStart;
        } else if (block.timestamp >= saleStart && block.timestamp <= saleEnd) {
            return State.running;
        } else {
            return State.afterEnd;
        }
    }

    event Invest(address investor, uint value, uint tokens);

    function invest() payable public returns (bool) {
        icoState = getCurrentState();
        require(icoState == State.running);

        require(msg.value >= minInvestment && msg.value <= maxInvestment);
        raisedAmount += msg.value;

        require(raisedAmount <= hardCap);

        uint tokens = msg.value / tokenPrice;

        balances[msg.sender] += tokens;
        balances[founder] -= tokens;
        deposit.transfer(msg.value);

        emit Invest(msg.sender, msg.value, tokens);

        return true;

    }

    receive() payable external {
        invest();
    }

    /* People invest in ICO want to make profit. Some of them will hold the tokens as a long term investment while others go to exchange after
    ICO has ended. 
    */

    function transfer(address to, uint tokens) public override returns(bool success) {
        require(block.timestamp > tokenTradeStart);
        super.transfer(to, tokens);    // Cryptos.transfer(to,tokens);
     
        return true;

    }

    function transferFrom(address from, address to, uint tokens) public override returns (bool success) {
        require(block.timestamp > tokenTradeStart);
        super.transferFrom(from, to, tokens);  // Cryptos.transfer(to,tokens); Copy the body codes of previous defined function

        return true;


    }

    /* Another practise is to burn tokens that have not been sold in the ICO. The ICO hardcap is 300 and that means we accept a max investment
    of 300 and sell tokens in value of 300 ETH. Of course the remaining tokens will be held in the owners wallet. If we burn these remaining tokens,
    will increase the token price.
    */

    function burn() public returns(bool) {
        icoState = getCurrentState();
        require(icoState == State.afterEnd);
        balances[founder] = 0;

        return true;

    /*
    // The tokens are vanished! There is no code in the contract that could create the tokens again. Note that function can be called by anyone,
    not only by the admin. This is a guarantee that the admin doesn't change his mind and in the end doesn't burn any of the tokens. Tokens will be 
    burned only after the ISO ends.

    */
    }




}
