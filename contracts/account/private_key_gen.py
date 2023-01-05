from starkware.crypto.signature.signature import (get_random_private_key,
                                                  private_to_stark_key)

prk = get_random_private_key()
print(f"STARKNET_PRIVATE_KEY : {prk}")

pbk = private_to_stark_key(prk)
print(f"STARKNET_PUBLIC_KEY  : {pbk}")
