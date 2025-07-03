# mqserver

## Introduction

* The MQ Server chart is a component of Cúram Platform responsible for providing an MQ instance for JMS processing. For more information about MQ, see [About IBM MQ](https://www.ibm.com/docs/en/ibm-mq/9.1?topic=mq-about).

## Chart Details

* Deployment of a single MQ instance (if desired).
* Deployment of a multi-instance MQ via NFS or Ceph (if desired).
* Starting from `curam-kubernetes` release `21.7.0`, chart versions have been updated to align with the release version.

## Prerequisites

* A configured NFS server (for use with NFS)
* A populated OpenShift Cluster (for use with Ceph)

### PodSecurityPolicy Requirements

Custom PodSecurityPolicy definition:

```
Not required as the underlying db2 instance runs with the default restricted policy
```

### SecurityContextConstraints Requirements

Custom SecurityContextConstraints definition:

```
Not required as the underlying db2 instance runs with the default restricted policy
```

## Configuration

See [Configuration reference](https://merative.github.io/curam-kubernetes/deployment/config-reference) section of the runbook.
