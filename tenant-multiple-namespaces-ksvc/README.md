# Multiple Namespaces per Tenant Knative with Kourier Setup

This setup is similar to the [Multiple Namespaces per Tenant Pod Setup](../tenant-multiple-namespaces-svc) 
using Knative Services instead of pods.

The Knative network layer is Kourier.

## Installing

Start a kind cluster with the Calico CNI plugin and Knative Serving:

```shell
$ ./hack/setup-kind-with-kn.sh
```



TODO: multi-tenant kourier installation

## Network Policies

Tenants are isolated (i.e. private services from tenantX are not accessible from tenantY) by applying
these network policies: 

- [denying all](policies-templates/deny-all.yaml) denying all ingress and egress traffic
- [allow-all-in-ns](policies-templates/allow-all-in-ns.yaml) allowing traffic between all pods within a (tenant) namespace (subsumed by the next policy)
- [allow-all-from-to-tenant-ns](policies-templates/allow-all-from-to-tenant-ns.yaml) allowing traffic between all pods spread
  across multiple namespaces for a given tenant.
- [allow-tenant-ingress-from-tenant](policies-templates/allow-tenant-ingress-from-tenant.yaml) allowing traffic from tenant namespaces to
  private tenant services ingress
- [allow-serving-to-tenant](policies-templates/allow-serving-to-tenant.yaml) allowing traffic from Knative Serving pods to
  tenant pods
- [allow-public-ingress-from-tenant](policies-templates/allow-tenant-ingress-from-tenant.yaml) allowing traffic from tenant namespaces to
  all public services ingress
 
TODO: describe network policies between knative-serving and kourier-system

![networkpolicies](./doc/networkpolicies.png?raw=true)

NOTE: for clarity, not all request paths are shown in this diagram.

## TODOs

- Restrict kourier controller RBAC to tenant namespaces
- Allow access to metrics 
- Non-activator path
