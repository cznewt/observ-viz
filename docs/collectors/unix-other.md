# unix.other

- **source**: node_exporter (unclassified families)
- **patterns**: `node_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.linux | raplPower | `node_rapl_package_joules_total` |
| system.linux | socketsMem | `node_sockstat_TCP_mem_bytes` |
| system.linux | socketsTcp | `node_sockstat_TCP_inuse` |
| system.linux | softnetDropped | `node_softnet_dropped_total` |
| system.linux | softnetSqueezed | `node_softnet_times_squeezed_total` |
| system.linux | tcpActiveOpens | `node_netstat_Tcp_ActiveOpens` |
| system.linux | tcpEstablished | `node_netstat_Tcp_CurrEstab` |
| system.linux | tcpInErrs | `node_netstat_Tcp_InErrs` |
| system.linux | tcpRetrans | `node_netstat_TcpExt_TCPSynRetrans` |
| system.linux | thermalZone | `node_thermal_zone_temp` |
| system.linux | udpQueues | `node_udp_queues` |

## Live metrics (140)

- `node_arp_entries`
- `node_authorizer_graph_actions_duration_seconds_bucket`
- `node_authorizer_graph_actions_duration_seconds_count`
- `node_authorizer_graph_actions_duration_seconds_sum`
- `node_cooling_device_cur_state`
- `node_cooling_device_max_state`
- `node_cpu_core_throttles_total`
- `node_cpu_guest_seconds_total`
- `node_cpu_package_throttles_total`
- `node_cpu_scaling_governor`
- `node_cpu_usage_seconds_total`
- `node_exporter_build_info`
- `node_forks_total`
- `node_netstat_Icmp6_InErrors`
- `node_netstat_Icmp6_InMsgs`
- `node_netstat_Icmp6_OutMsgs`
- `node_netstat_Icmp_InErrors`
- `node_netstat_Icmp_InMsgs`
- `node_netstat_Icmp_OutMsgs`
- `node_netstat_Ip6_InOctets`
- `node_netstat_Ip6_OutOctets`
- `node_netstat_IpExt_InOctets`
- `node_netstat_IpExt_OutOctets`
- `node_netstat_Ip_Forwarding`
- `node_netstat_TcpExt_ListenDrops`
- `node_netstat_TcpExt_ListenOverflows`
- `node_netstat_TcpExt_SyncookiesFailed`
- `node_netstat_TcpExt_SyncookiesRecv`
- `node_netstat_TcpExt_SyncookiesSent`
- `node_netstat_TcpExt_TCPOFOQueue`
- `node_netstat_TcpExt_TCPRcvQDrop`
- `node_netstat_TcpExt_TCPSynRetrans`
- `node_netstat_TcpExt_TCPTimeouts`
- `node_netstat_Tcp_ActiveOpens`
- `node_netstat_Tcp_CurrEstab`
- `node_netstat_Tcp_InErrs`
- `node_netstat_Tcp_InSegs`
- `node_netstat_Tcp_OutRsts`
- `node_netstat_Tcp_OutSegs`
- `node_netstat_Tcp_PassiveOpens`
- `node_netstat_Tcp_RetransSegs`
- `node_netstat_Udp6_InDatagrams`
- `node_netstat_Udp6_InErrors`
- `node_netstat_Udp6_NoPorts`
- `node_netstat_Udp6_OutDatagrams`
- `node_netstat_Udp6_RcvbufErrors`
- `node_netstat_Udp6_SndbufErrors`
- `node_netstat_UdpLite6_InErrors`
- `node_netstat_UdpLite_InErrors`
- `node_netstat_Udp_InDatagrams`
- `node_netstat_Udp_InErrors`
- `node_netstat_Udp_NoPorts`
- `node_netstat_Udp_OutDatagrams`
- `node_netstat_Udp_RcvbufErrors`
- `node_netstat_Udp_SndbufErrors`
- `node_nvme_info`
- `node_os_version`
- `node_processes_max_processes`
- `node_processes_max_threads`
- `node_processes_pids`
- `node_processes_state`
- `node_processes_threads`
- `node_processes_threads_state`
- `node_rapl_core_joules_total`
- `node_rapl_package_joules_total`
- `node_rapl_psys_joules_total`
- `node_rapl_uncore_joules_total`
- `node_scrape_collector_duration_seconds`
- `node_scrape_collector_success`
- `node_selinux_enabled`
- `node_sockstat_FRAG6_inuse`
- `node_sockstat_FRAG6_memory`
- `node_sockstat_FRAG_inuse`
- `node_sockstat_FRAG_memory`
- `node_sockstat_RAW6_inuse`
- `node_sockstat_RAW_inuse`
- `node_sockstat_TCP6_inuse`
- `node_sockstat_TCP_alloc`
- `node_sockstat_TCP_inuse`
- `node_sockstat_TCP_mem`
- `node_sockstat_TCP_mem_bytes`
- `node_sockstat_TCP_orphan`
- `node_sockstat_TCP_tw`
- `node_sockstat_UDP6_inuse`
- `node_sockstat_UDPLITE6_inuse`
- `node_sockstat_UDPLITE_inuse`
- `node_sockstat_UDP_inuse`
- `node_sockstat_UDP_mem`
- `node_sockstat_UDP_mem_bytes`
- `node_sockstat_sockets_used`
- `node_softnet_backlog_len`
- `node_softnet_cpu_collision_total`
- `node_softnet_dropped_total`
- `node_softnet_flow_limit_count_total`
- `node_softnet_processed_total`
- `node_softnet_received_rps_total`
- `node_softnet_times_squeezed_total`
- `node_textfile_mtime_seconds`
- `node_textfile_scrape_error`
- `node_thermal_zone_temp`
- `node_udp_queues`
- `node_xfs_allocation_btree_compares_total`
- `node_xfs_allocation_btree_lookups_total`
- `node_xfs_allocation_btree_records_deleted_total`
- `node_xfs_allocation_btree_records_inserted_total`
- `node_xfs_block_map_btree_compares_total`
- `node_xfs_block_map_btree_lookups_total`
- `node_xfs_block_map_btree_records_deleted_total`
- `node_xfs_block_map_btree_records_inserted_total`
- `node_xfs_block_mapping_extent_list_compares_total`
- `node_xfs_block_mapping_extent_list_deletions_total`
- `node_xfs_block_mapping_extent_list_insertions_total`
- `node_xfs_block_mapping_extent_list_lookups_total`
- `node_xfs_block_mapping_reads_total`
- `node_xfs_block_mapping_unmaps_total`
- `node_xfs_block_mapping_writes_total`
- `node_xfs_directory_operation_create_total`
- `node_xfs_directory_operation_getdents_total`
- `node_xfs_directory_operation_lookup_total`
- `node_xfs_directory_operation_remove_total`
- `node_xfs_extent_allocation_blocks_allocated_total`
- `node_xfs_extent_allocation_blocks_freed_total`
- `node_xfs_extent_allocation_extents_allocated_total`
- `node_xfs_extent_allocation_extents_freed_total`
- `node_xfs_inode_operation_attempts_total`
- `node_xfs_inode_operation_attribute_changes_total`
- `node_xfs_inode_operation_duplicates_total`
- `node_xfs_inode_operation_found_total`
- `node_xfs_inode_operation_missed_total`
- `node_xfs_inode_operation_reclaims_total`
- `node_xfs_inode_operation_recycled_total`
- `node_xfs_read_calls_total`
- `node_xfs_vnode_active_total`
- `node_xfs_vnode_allocate_total`
- `node_xfs_vnode_get_total`
- `node_xfs_vnode_hold_total`
- `node_xfs_vnode_reclaim_total`
- `node_xfs_vnode_release_total`
- `node_xfs_vnode_remove_total`
- `node_xfs_write_calls_total`
