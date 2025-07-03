# batch

## Introduction

* The Batch chart is a component of Cúram Platform responsible for running various batch (deferred) processes.

## Chart Details

* Creates cron jobs for executing various batch programs
* Starting from `curam-kubernetes` release `21.7.0`, chart versions have been updated to align with the release version.

## Prerequisites

* [`PodDisruptionBudgets`](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) are recommended for high resiliency in an application during risky operations, such as draining a node for maintenance or scaling down a cluster.

### PodSecurityPolicy Requirements

Custom PodSecurityPolicy definition:

```
Not required as the underlying IHS server runs with the default restricted policy
```

### SecurityContextConstraints Requirements

Custom SecurityContextConstraints definition:

```
Not required as the underlying IHS server runs with the default restricted policy
```

## Configuration

See [Configuration reference](https://merative.github.io/curam-kubernetes/deployment/config-reference) section of the runbook.
