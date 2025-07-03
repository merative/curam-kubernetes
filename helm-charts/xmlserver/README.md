# xmlserver

## Introduction

* XMLServer is a component of Cúram Platform responsible for producing PDF files for the SPM application.
* This component should not be deployed outside of the [`spm`](../spm) chart.
* Starting from `curam-kubernetes` release `21.7.0`, chart versions have been updated to align with the release version.

## Chart Details

* Deployment of a single pod listening on port 1800
* Exposed to SPM using a service for potential load balancing
* ![SPM 8.0.1.0](https://img.shields.io/badge/-SPM_8.0.1.0-green) Sample sidecar deployment provided for making XML server statistics available to Prometheus

## Prerequisites

* [`PodDisruptionBudgets`](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) are recommended for high resiliency in an application during risky operations, such as draining a node for maintenance or scaling down a cluster.

### PodSecurityPolicy Requirements

Custom PodSecurityPolicy definition:

```
Not required as XML server runs with the default restricted policy
```

### SecurityContextConstraints Requirements

Custom SecurityContextConstraints definition:

```
Not required as XML server runs with the default restricted policy
```

## Configuration

See [Configuration reference](https://merative.github.io/curam-kubernetes/deployment/config-reference) section of the runbook.
