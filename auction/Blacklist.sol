// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../access/AccessController.sol";

contract Blacklist is AccessController {

    mapping(string => bool) private _blacklists;

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _blacklists["BCOIN"] = true;
        _blacklists["BTC"] = true;
        _blacklists["ETH"] = true;
        _blacklists["BNB"] = true;
        _blacklists["ADA"] = true;
        _blacklists["USDT"] = true;
        _blacklists["DOT"] = true;
        _blacklists["XRP"] = true;
        _blacklists["UNI"] = true;
        _blacklists["LTC"] = true;
        _blacklists["LINK"] = true;
        _blacklists["BCH"] = true;
        _blacklists["XLM"] = true;
        _blacklists["LUNA"] = true;
        _blacklists["THETA"] = true;
        _blacklists["WBTC"] = true;
        _blacklists["USDC"] = true;
        _blacklists["DOGE"] = true;
        _blacklists["ATOM"] = true;
        _blacklists["AAVE"] = true;
        _blacklists["VET"] = true;
        _blacklists["AVAX"] = true;
        _blacklists["CTC"] = true;
        _blacklists["XMR"] = true;
        _blacklists["EOS"] = true;
        _blacklists["BSV"] = true;
        _blacklists["TRX"] = true;
        _blacklists["SOL"] = true;
        _blacklists["IOTA"] = true;
        _blacklists["CHZ"] = true;
        _blacklists["XEM"] = true;
        _blacklists["XTZ"] = true;
        _blacklists["ALGO"] = true;
        _blacklists["KSM"] = true;
        _blacklists["NEO"] = true;
        _blacklists["DAI"] = true;
        _blacklists["HT"] = true;
        _blacklists["SUSHI"] = true;
        _blacklists["HBAR"] = true;
        _blacklists["DASH"] = true;
        _blacklists["ENJ"] = true;
        _blacklists["LEO"] = true;
        _blacklists["DCR"] = true;
        _blacklists["ZIL"] = true;
        _blacklists["NEAR"] = true;
        _blacklists["TFUEL"] = true;
        _blacklists["BAT"] = true;
        _blacklists["BTT"] = true;
        _blacklists["RVN"] = true;
        _blacklists["ZEC"] = true;
        _blacklists["MANA"] = true;
        _blacklists["NEXO"] = true;
        _blacklists["MATIC"] = true;
        _blacklists["ETC"] = true;
        _blacklists["UMA"] = true;
        _blacklists["CAKE"] = true;
        _blacklists["RUNE"] = true;
        _blacklists["KLAY"] = true;
        _blacklists["YFI"] = true;
        _blacklists["CHSB"] = true;
        _blacklists["XWC"] = true;
        _blacklists["BNT"] = true;
        _blacklists["UST"] = true;
        _blacklists["OKT"] = true;
        _blacklists["HOT"] = true;
        _blacklists["CEL"] = true;
        _blacklists["ZRX"] = true;
        _blacklists["ICX"] = true;
        _blacklists["PXS"] = true;
        _blacklists["ONE"] = true;
        _blacklists["REN"] = true;
        _blacklists["WAVES"] = true;
        _blacklists["SC"] = true;
        _blacklists["R"] = true;
        _blacklists["FTM"] = true;
        _blacklists["ONT"] = true;
        _blacklists["DGB"] = true;
        _blacklists["STX"] = true;
        _blacklists["FLOW"] = true;
        _blacklists["FTT"] = true;
        _blacklists["OMG"] = true;
        _blacklists["OKB"] = true;
        _blacklists["BTMX"] = true;
        _blacklists["RENB"] = true;
        _blacklists["CELO"] = true;
        _blacklists["PAX"] = true;
        _blacklists["IOST"] = true;
        _blacklists["LRC"] = true;
        _blacklists["1INCH"] = true;
        _blacklists["NANO"] = true;
        _blacklists["ZKS"] = true;
        _blacklists["BTCV"] = true;
        _blacklists["QTUM"] = true;
        _blacklists["ZEN"] = true;
        _blacklists["CRV"] = true;
        _blacklists["OCEAN"] = true;
        _blacklists["KNC"] = true;
        _blacklists["HNT"] = true;
        _blacklists["BTG"] = true;
        _blacklists["QNT"] = true;
        _blacklists["LINA "] = true;
    }


    function addBlacklist(string memory symbol) public onlyAdmin{
        _blacklists[symbol] = true;
    }

    function addBlacklistInner(string memory symbol) public onlyTokenAuction{
        _blacklists[symbol] = true;
    }

    function deleteBlacklistInner(string memory symbol) public onlyTokenAuction{
        _blacklists[symbol] = false;
    }

    function isBlacklist(string memory symbol) public view returns(bool) {
        return _blacklists[symbol];
    }
}