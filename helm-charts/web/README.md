# web

## Introduction

* The `web` chart is a component of Cúram Platform responsible for providing the static content for the SPM application on Apache HTTP Server.
* This component should not be deployed outside of the [`spm`](../spm) chart.
* Starting from `curam-kubernetes` release `21.7.0`, chart versions have been updated to align with the release version.

## Chart Details

* Deployment of a single pod listening on port 8443
* Exposed to the cluster using a service for potential load balancing

## Prerequisites

* [`PodDisruptionBudgets`](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) are recommended for high resiliency in an application during risky operations, such as draining a node for maintenance or scaling down a cluster.

### PodSecurityPolicy Requirements

Custom PodSecurityPolicy definition:

```
Not required as web server runs with the default restricted policy
```

### SecurityContextConstraints Requirements

Custom SecurityContextConstraints definition:

```
Not required as web server runs with the default restricted policy
```

## Configuration

See [Configuration reference](https://merative.github.io/curam-kubernetes/deployment/config-reference) section of the runbook.
