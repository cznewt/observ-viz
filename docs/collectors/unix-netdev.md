# unix.netdev

- **source**: node_exporter
- **notes**: veth/cali interfaces excluded at collection.
- **patterns**: `node_network_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.linux | netRx | `node_network_receive_bytes_total` |
| system.linux | netRxDrop | `node_network_receive_drop_total` |
| system.linux | netRxErrs | `node_network_receive_errs_total` |
| system.linux | netRxExclLo | `node_network_receive_bytes_total` |
| system.linux | netTx | `node_network_transmit_bytes_total` |
| system.linux | netTxDrop | `node_network_transmit_drop_total` |
| system.linux | netTxErrs | `node_network_transmit_errs_total` |
| system.linux | netTxExclLo | `node_network_transmit_bytes_total` |

## Live metrics (36)

- `node_network_address_assign_type`
- `node_network_carrier`
- `node_network_carrier_changes_total`
- `node_network_carrier_down_changes_total`
- `node_network_carrier_up_changes_total`
- `node_network_device_id`
- `node_network_dormant`
- `node_network_flags`
- `node_network_iface_id`
- `node_network_iface_link`
- `node_network_iface_link_mode`
- `node_network_info`
- `node_network_mtu_bytes`
- `node_network_name_assign_type`
- `node_network_net_dev_group`
- `node_network_protocol_type`
- `node_network_receive_bytes_total`
- `node_network_receive_compressed_total`
- `node_network_receive_drop_total`
- `node_network_receive_errs_total`
- `node_network_receive_fifo_total`
- `node_network_receive_frame_total`
- `node_network_receive_multicast_total`
- `node_network_receive_nohandler_total`
- `node_network_receive_packets_total`
- `node_network_speed_bytes`
- `node_network_transmit_bytes_total`
- `node_network_transmit_carrier_total`
- `node_network_transmit_colls_total`
- `node_network_transmit_compressed_total`
- `node_network_transmit_drop_total`
- `node_network_transmit_errs_total`
- `node_network_transmit_fifo_total`
- `node_network_transmit_packets_total`
- `node_network_transmit_queue_length`
- `node_network_up`
