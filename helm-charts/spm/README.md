# spm

## Introduction

* The SPM chart is the umbrella Helm chart for Cúram Platform responsible for coordinating the deployment of the application across multiple subcharts.

## Chart Details

* Deployment of a single XML server replica
* Deployment of a single IHS replica with static content
* Deployment of a single MQ replica
* Deployment of a single Cúram application replica (one producer pod, one consumer pod)
* Starting from `curam-kubernetes` release `21.7.0`, chart versions have been updated to align with the release version.

## Prerequisites

* [`PodDisruptionBudgets`](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) are recommended for high resiliency in an application during risky operations, such as draining a node for maintenance or scaling down a cluster.

### PodSecurityPolicy Requirements

All of the components of SPM can be run under the `restricted` (default) security policy, with the exception of one scenario.

Custom PodSecurityPolicy definition:

```
None
```

### SecurityContextConstraints Requirements

All of the components of SPM can be run under the `restricted` (default) security context, with the exception of one scenario.

Custom SecurityContextConstraints definition:

```
None
```

## Configuration

See [Configuration reference](https://merative.github.io/curam-kubernetes/deployment/config-reference) section of the runbook.
