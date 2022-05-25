# Multiple Namespaces per Tenant Pod Setup

In this setup, there are two tenants both owning two namespaces.

In each tenant namespace, there are two pods created, `ping` and `pong`, `ping` sending a request to `pong` in the same
namespace every two seconds. A new TCP connection is created each time `ping`
sends a request, as network policies don't apply to existing connections.

Each namespace is annotated with the tenant ID (eg. `knative.dev/tenant: tenant1`).

The network policies are configured to allow all ingress and egress traffic from/to pods belonging to the same tenant.
Three network policies are applied:

- [denying all](./policies/deny-all.yaml) denying all ingress and egress traffic
- [allow-all-in-ns](./policies/allow-all-in-ns.yaml) allowing traffic between all pods within a (tenant) namespace
- [allow-all-from-to-tenant-ns](./policiesallow-all-from-to-tenant-ns.yaml) allowing traffic between all pods spread
  across multiple namespaces for a given tenant.

The second policy is not needed and just show how to transition from one namespace to multiple namespaces.

## Installing

Start a kind cluster with the Calico CNI plugin:

```shell
$ ./hack/setup-kind.sh
```

Then install the app:

```shell
$ kubectl apply -Rf tenant-multiple-namespaces-svc/config
```

Both pods and network policies are applied at the same time.

## Verifying

In the tenant1-ns1 namespace, look at `ping` logs:

```shell
$ kubectl -n tenant1-ns1 logs ping
2022/05/18 15:37:05 target:  http://pong.tenant1-ns1:8080
2022/05/18 15:37:07 ping failed: Get "http://pong.tenant1-ns1:8080": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
2022/05/18 15:37:09 ping succeeded
2022/05/18 15:37:11 ping succeeded
2022/05/18 15:37:13 ping succeeded
2022/05/18 15:37:15 ping succeeded
2022/05/18 15:37:17 ping succeeded
```

The first line shows the traffic was blocked before the one of the `allow` network policies was applied. Then the ping
when through.

In the same namespace (tenant1-ns1), `ping-ns2` sends a ping to `pong` in the `tenant1-ns2` namespace, belonging to the same tenant:


```shell
$ kubectl logs -n tenant1-ns1 ping-tenant2-ns1-fail -f
kubectl -n tenant1-ns1 logs ping-ns2 
2022/05/18 15:37:05 target:  http://pong.tenant1-ns2:8080
2022/05/18 15:37:07 ping failed: Get "http://pong.tenant1-ns2:8080": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
2022/05/18 15:37:11 ping failed: Get "http://pong.tenant1-ns2:8080": dial tcp 10.96.37.188:8080: i/o timeout (Client.Timeout exceeded while awaiting headers)
2022/05/18 15:37:13 ping succeeded
2022/05/18 15:37:15 ping succeeded
2022/05/18 15:37:17 ping succeeded
2022/05/18 15:37:19 ping succeeded
```

Finally, in the same namespace, `ping-tenant2-ns1-fail` tries to ping tenant2 ns1 pong pod, but the traffic is blocked, as expected:

```shell
$ kubectl logs -n tenant1-ns1 ping-tenant2-ns1-fail -f
kubectl logs -n tenant1-ns1 ping-tenant2-ns1-fail -f
2022/05/18 15:37:05 target:  http://pong.tenant2-ns1:8080
2022/05/18 15:37:07 ping failed: Get "http://pong.tenant2-ns1:8080": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
2022/05/18 15:37:11 ping failed: Get "http://pong.tenant2-ns1:8080": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
2022/05/18 15:37:15 ping failed: Get "http://pong.tenant2-ns1:8080": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
2022/05/18 15:37:19 ping failed: Get "http://pong.tenant2-ns1:8080": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
2022/05/18 15:37:23 ping failed: Get "http://pong.tenant2-ns1:8080": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```
