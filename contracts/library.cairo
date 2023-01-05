%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import keccak, finalize_keccak, keccak_add_uint256s
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_reverse_endian,
    uint256_unsigned_div_rem,
    uint256_mul,
    uint256_add,
)
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256

struct OpenOracleEntry {
    t_little: felt,
    p_little: felt,
    ticker_len_little: felt,
    ticker_name_little: felt,
    r_low: felt,
    r_high: felt,
    s_low: felt,
    s_high: felt,
    v: felt,
    public_key: felt,
}

struct Entry {
    key: felt,  // UTF-8 encoded lowercased string, e.g. "eth/usd"
    value: felt,
    timestamp: felt,
    source: felt,
    publisher: felt,
}

func word_reverse_endian_64{bitwise_ptr: BitwiseBuiltin*}(word: felt) -> (res: felt) {
    // A function to reverse the endianness of a 8 bytes (64 bits) integer.
    // The result will not make sense if word > 2^64.
    // The implementation is directly inspired by the function word_reverse_endian
    // from the common library starkware.cairo.common.uint256 with three steps instead of four.
    // This is useful to get back to usual big endian representation of timestamp, price, and ticker
    // to store them after the signature is verified.

    // Step 1.
    assert bitwise_ptr[0].x = word;
    assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
    tempvar word = word + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
    // Step 2.
    assert bitwise_ptr[1].x = word;
    assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
    tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
    // Step 3.
    assert bitwise_ptr[2].x = word;
    assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
    tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;

    let bitwise_ptr = bitwise_ptr + 3 * BitwiseBuiltin.SIZE;
    return (res=word / 2 ** (8 + 16 + 32));
}

func verify_oracle_message{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    t_little: felt,
    p_little: felt,
    ticker_len_little: felt,
    ticker_name_little: felt,
    r_low: felt,
    r_high: felt,
    s_low: felt,
    s_high: felt,
    v: felt,
    eth_address: felt,
) {
    alloc_locals;
    // keccak_ptr needs to be initialized to use the keccak functions
    let (keccak_ptr: felt*) = alloc();
    local keccak_ptr_start: felt* = keccak_ptr;
    let (local input: felt*) = alloc();

    // The keccak function in Cairo needs an input array of 8 bytes unsigned integers. All values and output are in little endian representation.
    // To retrieve the values, convert the orignal hex abi message into a bytes array, it will be 256 bytes length (two 64 bytes int + two 64 bytes strings).
    // Then convert each 8 bytes portion ([0,8|, [8, 16[, [16, 24[, ... [248,256[) to an integer in little endian representation.
    // It can be done using python's function int.from_bytes(b'8 bytes string', 'little')
    // Some values are hardcoded and will never change, the others are from the input (timestamp, price, ticker_len, ticker_name)

    assert input[0] = 0;  // 8
    assert input[1] = 0;  // 16
    assert input[2] = 0;  // 24
    assert input[3] = 9223372036854775808;  // 32
    assert input[4] = 0;  // 40
    assert input[5] = 0;  // 48
    assert input[6] = 0;  // 56
    assert input[7] = t_little;  // 64
    assert input[8] = 0;  // 72
    assert input[9] = 0;  // 80
    assert input[10] = 0;  // 88
    assert input[11] = 13835058055282163712;  // 96
    assert input[12] = 0;  // 104
    assert input[13] = 0;  // 112
    assert input[14] = 0;  // 120
    assert input[15] = p_little;  // 128
    assert input[16] = 0;  // 136
    assert input[17] = 0;  // 144
    assert input[18] = 0;  // 152
    assert input[19] = 432345564227567616;  // 160
    assert input[20] = 126879296746096;  // 168
    assert input[21] = 0;  // 176
    assert input[22] = 0;  // 184
    assert input[23] = 0;  // 192
    assert input[24] = 0;  // 200
    assert input[25] = 0;  // 208
    assert input[26] = 0;  // 216
    assert input[27] = ticker_len_little;  // 224
    assert input[28] = ticker_name_little;  // 232
    assert input[29] = 0;  // 240
    assert input[30] = 0;  // 248
    assert input[31] = 0;  // 256

    // Compute the keccak hash of the abi message (k_1)
    with keccak_ptr {
        let (local k_1: Uint256) = keccak(inputs=input, n_bytes=256);
    }

    let (local input2: Uint256*) = alloc();

    // Below is the hardcoded value of the integer representation of b'\x19Ethereum Signed Message:\n32', in little endian.
    // It is stored in a Uint256 since we want to concatenate it with k_1 which is an Uint256.
    local eth_signed_message: Uint256;
    assert eth_signed_message.low = 133449460819357165542986788045499680025;
    assert eth_signed_message.high = 15535954008750500564672269600;

    // Since the keccak function only uses 8 bytes integers as input and eth_signed_message is only 28 bytes length, we need to split k_1
    // to get its first 4 bytes. To do this, we need to divide k_1 by 256 (which 2^8 for 1 byte) four times. So we hardcode the 256^4 value.

    local d256_4: Uint256;
    assert d256_4.low = 4294967296;
    assert d256_4.high = 0;

    // When we divide k_1 by 256^4, the quotient will be the little endian representation of k_1 with the first 4 bytes removed.
    // Meaning if k_1=b'\x01\x02\x03\x04\x05\x06\x07\x08', the quotient of k_1/256^4 is q=b'\x05\x06\x07\x08\x00\x00\x00\x00'
    // And the remainder will be r=b'\x01\x02\x03\x04\x00\x00\x00\x00

    let (q, r) = uint256_unsigned_div_rem(k_1, d256_4);

    // Now we need to multiply the remainder by 256^28 to move the first 4 bytes of k_1 to the right,
    // Remember this is all litlle-endian so multiplying by 256 is equivalent to moving everything to the right.
    // Using our previous example above, multiplying r by 256^4 will give b'\x00\x00\x00\x00\x01\x02\x03\x04'

    local m256_28: Uint256;
    assert m256_28.low = 0;
    assert m256_28.high = 79228162514264337593543950336;

    let (m_r_low, _) = uint256_mul(r, m256_28);

    // Finally, we just need to add the remainder to eth_signed_message to concatenate the first 4 bytes and make the first input a proper 32 bytes (Uint256) value
    // If you followed well the example, eth_signed_message + m_r_low would give b'\x19Ethereum Signed Message:\n32\x01\x02\x03\x04'.

    let (m_low, _) = uint256_add(eth_signed_message, m_r_low);

    assert input2[0] = m_low;  // This is 32 bytes length, with eth_signed_message (28 bytes) + the first 4 bytes of k_1
    assert input2[1] = q;  // This is 28 bytes length, the last 28 bytes of k_1.

    let (inputs) = alloc();
    let inputs_start = inputs;

    // We use keccak_add_uint256s to properly format the the two 32 bytes (Uint256) input into an array of 8-bytes felts.

    keccak_add_uint256s{inputs=inputs}(n_elements=2, elements=input2, bigend=0);

    // Make sure the keccak function is computed with 60 bytes (32 + 28) so it ends at the right spot.

    with keccak_ptr {
        let (local message_hash: Uint256) = keccak(inputs=inputs_start, n_bytes=60);
    }

    // Reverse the endianness of message_hash to big endian representation because verify_eth_signature_uint256 works with big endian representation.

    let (message_hash) = uint256_reverse_endian(message_hash);

    local R: Uint256;
    local S: Uint256;
    assert R.low = r_low;
    assert R.high = r_high;

    assert S.low = s_low;
    assert S.high = s_high;

    // verify_eth_signature_uint256 contains asserts statements that will fail if the signature is wrong for this message_hash and this address

    with keccak_ptr {
        verify_eth_signature_uint256(msg_hash=message_hash, r=R, s=S, v=v, eth_address=eth_address);
    }

    // After we are done with using keccak functions, we call finalize_keccak to prevent malicious prover actions.
    finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);

    return ();
}
