# Node exporter runbooks

The `system.linux` (node-exporter) observ-lib ships the alerts below. Each
`runbook_url` points to its canonical runbook at the **prometheus-operator**
runbooks — <https://runbooks.prometheus-operator.dev/runbooks/node/>.

| Alert | Severity | Summary | Runbook |
|-------|----------|---------|---------|
| `NodeFilesystemSpaceFillingUp` | warning/critical | Filesystem is predicted to run out of space within the next 24 hours. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemspacefillingup) |
| `NodeFilesystemAlmostOutOfSpace` | warning/critical | Filesystem has less than 5% space left. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemalmostoutofspace) |
| `NodeFilesystemFilesFillingUp` | warning/critical | Filesystem is predicted to run out of inodes within the next 24 hours. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemfilesfillingup) |
| `NodeFilesystemAlmostOutOfFiles` | warning/critical | Filesystem has less than 5% inodes left. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemalmostoutoffiles) |
| `NodeNetworkReceiveErrs` | warning | Network interface is reporting many receive errors. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodenetworkreceiveerrs) |
| `NodeNetworkTransmitErrs` | warning | Network interface is reporting many transmit errors. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodenetworktransmiterrs) |
| `NodeHighNumberConntrackEntriesUsed` | warning | Number of conntrack are getting close to the limit. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodehighnumberconntrackentriesused) |
| `NodeTextFileCollectorScrapeError` | warning | Node Exporter text file collector failed to scrape. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodetextfilecollectorscrapeerror) |
| `NodeClockSkewDetected` | warning | Clock skew detected. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodeclockskewdetected) |
| `NodeClockNotSynchronising` | warning | Clock not synchronising. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodeclocknotsynchronising) |
| `NodeRAIDDegraded` | critical | RAID Array is degraded. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/noderaiddegraded) |
| `NodeRAIDDiskFailure` | warning | Failed device in RAID array. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/noderaiddiskfailure) |
| `NodeFileDescriptorLimit` | warning/critical | Kernel is predicted to exhaust file descriptors limit soon. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodefiledescriptorlimit) |
| `NodeCPUHighUsage` | info | High CPU usage. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodecpuhighusage) |
| `NodeSystemSaturation` | warning | System saturated, load per core is very high. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodesystemsaturation) |
| `NodeMemoryMajorPagesFaults` | warning | Memory major page faults are occurring at very high rate. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodememorymajorpagesfaults) |
| `NodeMemoryHighUtilization` | warning | Host is running out of memory. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodememoryhighutilization) |
| `NodeDiskIOSaturation` | warning | Disk IO queue is high. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodediskiosaturation) |
| `NodeSystemdServiceFailed` | warning | Systemd service has entered failed state. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodesystemdservicefailed) |
| `NodeSystemdServiceCrashlooping` | warning | Systemd service keeps restaring, possibly crash looping. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodesystemdservicecrashlooping) |
| `NodeBondingDegraded` | warning | Bonding interface is degraded. | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodebondingdegraded) |
