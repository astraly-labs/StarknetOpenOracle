import json
import logging
import time
from typing import Union

from client_tools import fetch_coinbase, fetch_okx, prepare_contract_call_args
# from empiric.core.base_client import EmpiricAccountClient, EmpiricBaseClient
from empiric.core.client import EmpiricClient
from empiric.core.types import HEX_STR
from starknet_py.contract import Contract
from starknet_py.net.client_errors import ClientError
from starknet_py.net import AccountClient

logger = logging.getLogger(__name__)


class EmpiricAccountClient(AccountClient):
    async def _get_nonce(self) -> int:
        return int(time.time())

class OpenOracleClient(EmpiricClient):
    def __init__(
        self,
        open_oracle_address: HEX_STR,
        account_contract_address: Union[int, HEX_STR],
        account_private_key: int,
    ):
        super().__init__(
            account_private_key=account_private_key,
            account_contract_address=account_contract_address,
        )

        # Overwrite account_client with timestamp-based nonce
        self.client = EmpiricAccountClient(
            account_contract_address, self.client, self.signer
        )

        # OpenOracle contract
        open_oracle_abi = open("build/OpenOraclePublisher_abi.json", "r")
        self.open_oracle_contract = Contract(
            address=open_oracle_address,
            abi=json.load(open_oracle_abi),
            client=self.client,
        )
        open_oracle_abi.close()

    async def publish_open_oracle_entries_okx(
        self, assets=["btc", "eth", "dai"]
    ) -> hex:
        okx_oracle_data = fetch_okx(assets=assets)
        calls = [
            self.open_oracle_contract.functions["publish_entry"].prepare(
                prepare_contract_call_args(*oracle_data)
            )
            for oracle_data in okx_oracle_data
        ]

        return await self.send_transactions(calls=calls)

    async def publish_open_oracle_entries_okx_sequential(self, assets: list):
        okx_oracle_data = fetch_okx(assets=assets)
        calls = [
            self.open_oracle_contract.functions["publish_entry"].prepare(
                prepare_contract_call_args(*oracle_data)
            )
            for oracle_data in okx_oracle_data
        ]
        results = {
            "OKX:"
            + asset_call[0].upper(): await self.send_transactions(calls=[asset_call[1]])
            for asset_call in zip(assets, calls)
        }
        return results

    async def publish_open_oracle_entries_coinbase(self, assets: list) -> hex:
        coinbase_oracle_data = fetch_coinbase(assets=assets)
        calls = [
            self.open_oracle_contract.functions["publish_entry"].prepare(
                prepare_contract_call_args(*oracle_data)
            )
            for oracle_data in coinbase_oracle_data
        ]

        return await self.send_transactions(calls=calls)

    async def publish_open_oracle_entries_coinbase_sequential(self, assets: list):
        coinbase_oracle_data = fetch_coinbase(assets=assets)
        calls = [
            self.open_oracle_contract.functions["publish_entry"].prepare(
                prepare_contract_call_args(*oracle_data)
            )
            for oracle_data in coinbase_oracle_data
        ]

        results = {
            "Coinbase:"
            + asset_call[0].upper(): await self.send_transactions(calls=[asset_call[1]])
            for asset_call in zip(assets, calls)
        }
        return results

    async def publish_open_oracle_entries_all_publishers(self, assets: list) -> hex:
        okx_oracle_data = fetch_okx(assets=assets)
        coinbase_oracle_data = fetch_coinbase(assets=assets)
        all_data = okx_oracle_data + coinbase_oracle_data

        calls = [
            self.open_oracle_contract.functions["publish_entry"].prepare(
                prepare_contract_call_args(*oracle_data)
            )
            for oracle_data in all_data
        ]
        return await self.send_transactions(calls=calls)

    async def publish_open_oracle_entries_all_publishers_sequential(
        self, assets: list, n_retries=3
    ) -> hex:
        results_okx = {}
        for attempt in range(n_retries):
            try:
                results_okx = await self.publish_open_oracle_entries_okx_sequential(
                    assets
                )
                break
            except ClientError as e:
                logger.warning(
                    f"Client error {e} at {attempt} attempt for OKX, retrying"
                )
                time.sleep(10)

        results_cb = {}
        for attempt in range(n_retries):
            try:
                results_cb = await self.publish_open_oracle_entries_coinbase_sequential(
                    assets
                )
                break
            except ClientError as e:
                logger.warning(
                    f"Client error {e} at {attempt} attempt for Coinbase, retrying"
                )
                time.sleep(10)

        results = {**results_okx, **results_cb}
        return results
