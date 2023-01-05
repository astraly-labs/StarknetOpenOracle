import base64
import datetime
import hmac
import logging
import os
from hashlib import sha256
from typing import List, Tuple

import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def to_uint(a):
    """Takes in value, returns uint256-ish tuple."""
    return (a & ((1 << 128) - 1), a >> 128)


def remove_0x_if_present(eth_hex_data: str) -> str:
    if eth_hex_data[0:2].upper() == "0X":
        return eth_hex_data[2:]
    else:
        return eth_hex_data


def fetch_okx(assets: List[str] = ["btc", "eth", "dai"]) -> List[Tuple[str, str, str]]:
    okx_wallet_address = "85615b076615317c80f14cbad6501eec031cd51c"  # from api docs

    r = requests.get("https://www.okx.com/api/v5/market/open-oracle")
    r_dict = r.json()["data"][0]
    messages = r_dict["messages"]
    signatures = r_dict["signatures"]
    tickers = [
        bytes.fromhex(remove_0x_if_present(m))[224:232].split(b"\x00")[0].decode()
        for m in messages
    ]

    result = []
    for asset in assets:
        try:
            index = tickers.index(asset.upper())
            result.append((messages[index], signatures[index], okx_wallet_address))
        except ValueError:
            logger.info(
                f"Asset {asset.upper()} not available in OKX signed messages, skipping"
            )
            pass

    return result


def fetch_coinbase(
    assets: List[str] = ["btc", "eth", "dai"]
) -> List[Tuple[str, str, str]]:
    coinbase_wallet_address = "0xfCEAdAFab14d46e20144F48824d0C09B1a03F2BC"
    COINBASE_API_SECRET = os.getenv("COINBASE_API_SECRET")
    COINBASE_API_KEY = os.getenv("COINBASE_API_KEY")
    COINBASE_API_PASSPHRASE = os.environ.get("COINBASE_API_PASSPHRASE")
    URL = "https://api.exchange.coinbase.com"
    REQUEST_PATH = "/oracle"
    METHOD = "GET"
    request_timestamp = str(
        int(
            datetime.datetime.now(datetime.timezone.utc)
            .replace(tzinfo=datetime.timezone.utc)
            .timestamp()
        )
    )
    signature = hmac.new(
        base64.b64decode(COINBASE_API_SECRET),
        (request_timestamp + METHOD + REQUEST_PATH).encode("ascii"),
        sha256,
    )
    headers = {
        "Accept": "application/json",
        "CB-ACCESS-KEY": COINBASE_API_KEY,
        "CB-ACCESS-SIGN": base64.b64encode(signature.digest()),
        "CB-ACCESS-TIMESTAMP": request_timestamp,
        "CB-ACCESS-PASSPHRASE": COINBASE_API_PASSPHRASE,
    }

    response = requests.request(METHOD, URL + REQUEST_PATH, headers=headers, timeout=10)

    response.raise_for_status()
    response = response.json()
    messages = response["messages"]
    signatures = response["signatures"]

    result = []
    tickers = [
        bytes.fromhex(remove_0x_if_present(m))[224:232].split(b"\x00")[0].decode()
        for m in messages
    ]
    for asset in assets:
        try:
            index = tickers.index(asset.upper())
            result.append((messages[index], signatures[index], coinbase_wallet_address))
        except ValueError:
            logger.info(
                f"Asset {asset.upper()} not available in Coinbase signed messages, skipping"
            )
            pass

    return result


def prepare_contract_call_args(
    oracle_message_hex: str, oracle_signature_hex: str, eth_wallet_address: str
) -> dict:
    message_bytes = bytes.fromhex(remove_0x_if_present(oracle_message_hex))
    signature_bytes = bytes.fromhex(remove_0x_if_present(oracle_signature_hex))

    timestamp_little_endian = int.from_bytes(message_bytes[56:64], "little")
    price_little_endian = int.from_bytes(message_bytes[120:128], "little")
    ticker_len_little_endian = int.from_bytes(message_bytes[216:224], "little")
    ticker_little_endian = int.from_bytes(message_bytes[224:232], "little")

    signature_r_big = int.from_bytes(signature_bytes[0:32], "big")
    signature_s_big = int.from_bytes(signature_bytes[32:64], "big")
    signature_v_big = int.from_bytes(signature_bytes[64:96], "big")

    signature_r_uint256 = to_uint(signature_r_big)
    signature_s_uint256 = to_uint(signature_s_big)

    eth_address_big = int(remove_0x_if_present(eth_wallet_address), 16)
    logger.info(f"Trying to publish {message_bytes[224:227]} price {int.from_bytes(message_bytes[120:128], 'big')} at timestamp {int.from_bytes(message_bytes[56:64],'big')} from publisher {eth_wallet_address}")

    if signature_v_big == 27 or signature_v_big == 28:
        signature_v_big -= 27  # See https://github.com/starkware-libs/cairo-lang/blob/13cef109cd811474de114925ee61fd5ac84a25eb/src/starkware/cairo/common/cairo_secp/signature.cairo#L173-L174

    contract_call_args = {
        "t_little": timestamp_little_endian,
        "p_little": price_little_endian,
        "ticker_len_little": ticker_len_little_endian,
        "ticker_name_little": ticker_little_endian,
        "r_low": signature_r_uint256[0],
        "r_high": signature_r_uint256[1],
        "s_low": signature_s_uint256[0],
        "s_high": signature_s_uint256[1],
        "v": signature_v_big,
        "public_key": eth_address_big,
    }
    return contract_call_args
