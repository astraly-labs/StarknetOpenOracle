import asyncio
import logging
import os

from dotenv import load_dotenv

from client import OpenOracleClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

load_dotenv("client/.env")
account_private_key = int(os.getenv("ACCOUNT_PRIVATE_KEY"), 0)
account_contract_address = int(os.getenv("ACCOUNT_CONTRACT_ADDRESS"), 0)


OPEN_ORACLE_ADDRESS = (
    "0x010660d8f0c7403d696e5b3fdca2ef6630f9cd8102f9d3dd4cc65a82904aa8d7"
)


async def main():
    c: OpenOracleClient
    c = OpenOracleClient(
        open_oracle_address=OPEN_ORACLE_ADDRESS,
        account_contract_address=account_contract_address,
        account_private_key=account_private_key,
    )

    assets = ["btc", "eth"]
    results = await c.publish_open_oracle_entries_all_publishers_sequential(
        assets, n_retries=3
    )

    for k in results:
        print(f"Published latest Open Oracle {k} data with tx: {results[k]}")


if __name__ == "__main__":

    asyncio.run(main())
