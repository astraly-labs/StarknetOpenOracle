# StarkNet-Open-Oracle

### What is the Open Oracle standard?
Compound and Coinbase were tired with the status quo of black box off-chain oracles on Ethereum so they collaborated to create the open oracle standard. This initiative created an open standard that anyone could use to trustlessly bring data on-chain, without requiring custom integrations with data sources or relying on third parties for secure data.

It allows a *Source* (also called a *Reporter*) (typically a trusted source like an exchange) to sign a message containing price data in a standardized way with a private key.

A *Publisher* can then use this signed message to put the price data on-chain.

Using the *Source*'s public key to verify the message's signature, there is no need to trust the *Publisher* for correctly reporting the data from the *Source*.


In April 2020, [Coinbase started providing an Open Oracle compatible signed price feed](https://blog.coinbase.com/introducing-the-coinbase-price-oracle-6d1ee22c7068) so that anyone can publish their data on chain.
They were [followed by OKX](https://www.okx.com/academy/en/okex-enhances-support-for-defi-growth-with-its-secure-price-feed-okex-oracle) the same year.


This repository ports the on-chain [verification contracts](https://github.com/compound-finance/open-oracle/blob/0e148fdb0e8cbe4d412548490609679621ab2325/contracts/OpenOracleData.sol#L40-L43) of the standard from Ethereum over to StarkNet.


## Setup for development  
Install Protostar. Clone the repository. Use python 3.7.

```bash
python -m venv env
source env/bin/activate
pip install -r requirements.txt
```

Testing contracts (local contract deployment with protostar cool features takes some time so be patient)

```
protostar test tests/
```

Use `protostar test --disable-hint-validation tests/` if using hints in the main Contract.

## Using the client to publish signed prices  

First, compile the contracts. The compiled contracts and their ABI will be stored in the  `build/` directory. 

```bash
protostar build
```

### 1. Use a Starknet account with modified nonce validation 

Due to some Starknet limitations, it is not possible yet to do multiple contract calls in one transaction with the Open Oracle contracts.  
This should be fixed when the keccak builtin will be out along with other scalability improvements.  

In order to send multiple transactions at the same time from the python client, you will need a special type of account with a modified type of nonce.


Here are the steps to create and deploy this type of account : 

```bash 
python contracts/account/private_key_gen.py
```

Retrieve the `STARKNET_PRIVATE_KEY` and the `STARKNET_PUBLIC_KEY` from the output.
Then deploy your account with your public key as input parameter for the constructor : 

```bash
protostar deploy build/AccountTimestampNonce.json -i STARKNET_PUBLIC_KEY --network alpha-goerli
```

Retrieve the `Contract address` you will get as an output. 

Don't forget to send some ETH to this address for the gas fees. 

### 2. Use the client to publish prices 

#### 2.1. Fill the envirnonment variables 
You should now be able to fill the necessary environment variables in `client/.env(fill_and_rename_to.env`  
Don't forget to rename the file to just  `.env` when you are done!  

Fill it using : 

- your StarkNet account private key as an integer
- your StarkNet account contract address
- optionally, Coinbase API keys with “view” permission if you want to fetch signed prices from Coinbase.
Note that OKX doesn't require any API keys to fetch its signed prices.

#### 2.2. Choose the assets and sources you need 

After that, edit the function `main()` in `client/main.py` so you can choose your assets, and if you want to fetch prices either from:
- OKX (use `c.publish_open_oracle_entries_okx_sequential`)
- Coinbase (use `c.publish_open_oracle_entries_coinbase_sequential`)
- both (use `c.publish_open_oracle_entries_all_publishers_sequential`).

Supported assets are:
- BTC, ETH, DAI, ZRX, BAT, KNC, LINK, COMP (for both Coinbase and OKX)
- XTZ, REP, UNI, GRT, SNX. (for Coinbase only)

```python
async def main():
    c = OpenOracleClient()
    await c.publish_open_oracle_entries_all_publishers_sequential(assets=['btc', 'eth'])
```

#### 2.3. Run either locally or with Docker  

##### - Locally
Make sure you have activated the virtual env and just run 
```
python client/main.py
```


##### - With a Docker container

```bash
docker build -t python-open-oracle-client .
docker run --env-file client/.env  python-open-oracle-client
```

## Contract deployment and current address

To deploy the contract, just use protostar like this:

```bash
protostar build
protostar deploy build/OpenOraclePublisher.json --network alpha-goerli
```

The current version of the contract is deployed here: https://goerli.voyager.online/contract/0x010660d8f0c7403d696e5b3fdca2ef6630f9cd8102f9d3dd4cc65a82904aa8d7

The contract address is also stored in the variable `OPEN_ORACLE_ADDRESS` in `client/main.py`.
