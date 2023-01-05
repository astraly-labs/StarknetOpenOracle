%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.pow import pow
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_equal

from contracts.library import verify_oracle_message, word_reverse_endian_64, OpenOracleEntry, Entry

@contract_interface
namespace IOracleController {
    func publish_entry(entry: Entry) {
    }
    func get_decimals(key: felt) -> (decimals: felt) {
    }
    func get_admin_address() -> (admin_address: felt) {
    }
}

// ------------------
// EVENTS
// ------------------

@event
func empiric_oracle_controller_address_changed(new_contract_address: felt) {
}
@event
func empiric_admin_address_changed(old_admin_address: felt, new_admin_address: felt) {
}

// ------------------
// STORAGE VARS
// ------------------

@storage_var
func empiric_oracle_controller_address() -> (address: felt) {
}
@storage_var
func empiric_admin_address() -> (address: felt) {
}
@storage_var
func public_keys(index: felt) -> (public_key: felt) {
}
@storage_var
func public_keys_len() -> (len: felt) {
}
@storage_var
func public_key_to_source_name(public_key: felt) -> (source_name: felt) {
}
@storage_var
func ticker_name_little_to_empiric_key(ticker_name_little: felt) -> (key: felt) {
}
@storage_var
func decimals_cache(oracle_address, key) -> (decimals: felt) {
}

// ------------------
// VIEW FUNCTIONS
// ------------------

@view
func get_all_public_keys{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    public_keys_len: felt, public_keys: felt*
) {
    alloc_locals;
    let (local len) = public_keys_len.read();
    let (public_keys: felt*) = alloc();

    get_all_public_keys_loop(public_keys, 0, len);

    return (len, public_keys);
}

func get_all_public_keys_loop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    array: felt*, index: felt, max: felt
) {
    if (index == max) {
        return ();
    }
    let (public_key) = public_keys.read(index);
    assert [array] = public_key;

    get_all_public_keys_loop(array + 1, index + 1, max);
    return ();
}

@view
func get_empiric_oracle_controller_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() -> (address: felt) {
    let (oracle_controller_address) = empiric_oracle_controller_address.read();
    return (oracle_controller_address,);
}
@view
func get_empiric_admin_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (admin_address: felt) {
    let (admin_address) = empiric_admin_address.read();
    return (admin_address,);
}

// ------------------
// CONSTRUCTOR
// ------------------

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    public_keys.write(index=0, value=761466874539515783303110363281120649054760260892);
    public_keys.write(index=1, value=1443903124408663179676923566941061880487545664188);

    public_keys_len.write(2);

    public_key_to_source_name.write(
        public_key=761466874539515783303110363281120649054760260892, value='oo-okx'
    );
    public_key_to_source_name.write(
        public_key=1443903124408663179676923566941061880487545664188, value='oo-coinbase'
    );

    ticker_name_little_to_empiric_key.write(ticker_name_little=4412482, value='btc/usd');  // BTC
    ticker_name_little_to_empiric_key.write(ticker_name_little=4740165, value='eth/usd');  // ETH
    ticker_name_little_to_empiric_key.write(ticker_name_little=5919832, value='xtz/usd');  // XTZ
    ticker_name_little_to_empiric_key.write(ticker_name_little=4800836, value='dai/usd');  // DAI
    ticker_name_little_to_empiric_key.write(ticker_name_little=5260626, value='rep/usd');  // REP
    ticker_name_little_to_empiric_key.write(ticker_name_little=5788250, value='zrx/usd');  // ZRX
    ticker_name_little_to_empiric_key.write(ticker_name_little=5521730, value='bat/usd');  // BAT
    ticker_name_little_to_empiric_key.write(ticker_name_little=4410955, value='knc/usd');  // KNC
    ticker_name_little_to_empiric_key.write(ticker_name_little=1263421772, value='link/usd');  // LINK
    ticker_name_little_to_empiric_key.write(ticker_name_little=1347243843, value='comp/usd');  // COMP
    ticker_name_little_to_empiric_key.write(ticker_name_little=4804181, value='uni/usd');  // UNI
    ticker_name_little_to_empiric_key.write(ticker_name_little=5526087, value='grt/usd');  // GRT
    ticker_name_little_to_empiric_key.write(ticker_name_little=5787219, value='snx/usd');  // SNX

    empiric_oracle_controller_address.write(
        value=0x012fadd18ec1a23a160cc46981400160fbf4a7a5eed156c4669e39807265bcd4
    );

    empiric_admin_address.write(
        value=0x0704cc0f2749637a0345d108ac9cd597bb33ccf7f477978d52e236830812cd98
    );
    return ();
}

// ------------------
// EXTERNAL FUNCTIONS
// ------------------
func only_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (caller_address) = get_caller_address();
    let (admin_address) = empiric_admin_address.read();
    with_attr error_message("Admin: Called by non-admin contract") {
        assert caller_address = admin_address;
    }
    return ();
}

// Only empiric admin can call this function to update Oracle Controller address if it has changed.
@external
func update_empiric_oracle_controller_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(new_contract_address: felt) {
    only_admin();
    empiric_oracle_controller_address.write(new_contract_address);
    empiric_oracle_controller_address_changed.emit(new_contract_address);
    return ();
}

// Anyone can call this function to make sure the admin of the Oracle Controller and the admin of this contract are synced.

@external
func update_empiric_admin_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    let (oracle_controller_address) = empiric_oracle_controller_address.read();
    let (new_admin_address) = IOracleController.get_admin_address(
        contract_address=oracle_controller_address
    );
    let (current_admin_address) = empiric_admin_address.read();
    with_attr error_message(
            "Empiric admin address is already synced with the Oracle Controller contract") {
        assert_not_equal(current_admin_address, new_admin_address);
    }
    empiric_admin_address.write(new_admin_address);
    empiric_admin_address_changed.emit(current_admin_address, new_admin_address);
    return ();
}

@external
func publish_entry{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(entry: OpenOracleEntry) {
    alloc_locals;
    let proposed_public_key = entry.public_key;
    let (source_name) = public_key_to_source_name.read(public_key=proposed_public_key);

    with_attr error_message(
            "The Ethereum address that supposedly signed this message does not come from OpenOracle registered signers") {
        assert_not_equal(source_name, 0);
    }

    let ticker_name_little = entry.ticker_name_little;
    let (key) = ticker_name_little_to_empiric_key.read(ticker_name_little);

    with_attr error_message("This ticker name is not supported by Empiric Network") {
        assert_not_equal(key, 0);
    }

    with_attr error_message("Signature verification for the OpenOracleEntry provided failed") {
        verify_oracle_message(
            entry.t_little,
            entry.p_little,
            entry.ticker_len_little,
            entry.ticker_name_little,
            entry.r_low,
            entry.r_high,
            entry.s_low,
            entry.s_high,
            entry.v,
            entry.public_key,
        );
    }

    let (price) = word_reverse_endian_64(entry.p_little);
    let (timestamp) = word_reverse_endian_64(entry.t_little);

    let (decimals) = get_or_update_from_decimals_cache(key=key);
    let (multiplier) = pow(10, decimals - 6);
    let price = price * multiplier;

    local oracle_controller_entry: Entry;

    assert oracle_controller_entry.key = key;
    assert oracle_controller_entry.value = price;
    assert oracle_controller_entry.timestamp = timestamp;
    assert oracle_controller_entry.source = source_name;
    assert oracle_controller_entry.publisher = 'openoracle2';

    let (controller_address) = empiric_oracle_controller_address.read();

    IOracleController.publish_entry(
        contract_address=controller_address, entry=oracle_controller_entry
    );

    return ();
}

func get_or_update_from_decimals_cache{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(key: felt) -> (decimals: felt) {
    let (oracle_controller_address) = empiric_oracle_controller_address.read();
    let (decimals) = decimals_cache.read(oracle_controller_address, key);
    if (decimals == 0) {
        let (controller_address) = empiric_oracle_controller_address.read();
        let (new_decimals) = IOracleController.get_decimals(
            contract_address=controller_address, key=key
        );
        decimals_cache.write(oracle_address=oracle_controller_address, key=key, value=new_decimals);
        return (new_decimals,);
    }
    return (decimals,);
}
