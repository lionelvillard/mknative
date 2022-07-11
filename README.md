# Knative Multi-Tenancy with Kourier

This guide provides instructions on how to setup a multi-tenant Knative cluster.
It contains three sections:
- the first section describes how to install Knative Serving with the traffic isolation feature turned on.
- the second section explains how to manually create new tenants
- and finally the third section walks you through the steps to run the demo

## Knative Setup using Kind

Start a kind cluster with the Calico CNI plugin and Knative Serving:

```shell
$ ./hack/setup-kind-with-kn.sh
```

Then clone `net-kourier` and check out the patched Kourier (the easiest way is to use
the [GitHub CLI](https://cli.github.com)):

```shell
$ gh pr checkout 852
```

And deploy (you need [ko](https://github.com/google/ko)):

```
$ ko apply -f config
```

Enable port-level network isolation:

```shell
$ kubectl patch configmap/config-kourier \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"traffic-isolation":"port"}}'
```

And you are all set!

## Administrative tasks

This section walks you through the steps of adding and removing tenant to/from a cluster.

### Adding a new tenant

When adding a new tenant, you need to:
- create a tenant identifier to be used by Envoy. The tenant identifier is later
  referred as `listener`
- assign a unique networking port to this tenant. Any port number above 9443 can use.
  The tenant port number is later referred as `<listener-port>`.
- create a Kubernetes service in `kourier-system` exposing the tenant Envoy listener:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kourier-isolation-<listenerPort>
  namespace: kourier-system
  labels:
    networking.knative.dev/ingress-provider: kourier
    app.kubernetes.io/component: net-kourier
    app.kubernetes.io/version: devel
    app.kubernetes.io/name: knative-serving
spec:
  ports:
    - name: http2
      port: 80
      protocol: TCP
      targetPort: <listener-port>
  selector:
    app: 3scale-kourier-gateway
  type: ClusterIP
```

- create network policies to isolate tenants and allow traffic between Knative system services
  and tenant services:

    - [denying all](policies-templates/deny-all.yaml) denying all ingress and egress traffic
    - [allow-all-in-ns](policies-templates/allow-all-in-ns.yaml) allowing traffic between all pods within a (tenant)
      namespace (subsumed by the next policy)
    - [allow-all-from-to-tenant-ns](policies-templates/allow-all-from-to-tenant-ns.yaml) allowing traffic between all pods
      spread across multiple namespaces for a given tenant.
    - [allow-tenant-ingress-from-tenant](policies-templates/allow-tenant-ingress-from-tenant.yaml) allowing traffic from
      tenant namespaces to private tenant services ingress
    - [allow-serving-to-tenant](policies-templates/allow-serving-to-tenant.yaml) allowing traffic from Knative Serving pods
      to tenant pods
    - [allow-public-ingress-from-tenant](policies-templates/allow-tenant-ingress-from-tenant.yaml) allowing traffic from
      tenant namespaces to all public services ingress

![networkpolicies](./doc/networkpolicies.png?raw=true)

> NOTE: for clarity, not all request paths are shown in this diagram.

> NOTE: only network policies allowing traffic between Knative services are described. In
> particular those network policies don't allow traffic outside a Kubernetes cluster.

### Assigning a namespace to a tenant

Create a namespace and then add this annotation:

- `kourier.knative.dev/listener-port`: the envoy listener port

There can be multiple namespaces sharing the same annotation value.

Kourier does not check the provided value is valid, so be careful.

The annotation must be added before allowing the creation of Knative services in the namespace.

### Deleting a tenant namespace

No specific actions need to be performed.

### Deleting a tenant

Delete the `kourier-isolation-<listener-port>` service associated to the tenant

## Demo

The demo in this repository shows two tenants sharing the same Knative instance,
with both tenants owning two namespaces.

In each tenant namespace, two pods are created, `ping` and `pong`, `ping` sending a request to `pong` in the same
namespace every two seconds. A new TCP connection is created each time `ping`
sends a request, as network policies don't apply to existing connections.

### Deploying the admin objects

```shell
kubectl apply -Rf ./config/admin
```

### Deploying the tenants services

For tenant1:

```shell
kubectl apply -Rf ./config/tenant1
```

and tenant2: 

```shell
kubectl apply -Rf ./config/tenant2
```

### Verifying

In the tenant1-ns1 namespace, get the logs for `ping-XXX`:

```shell
$ kubectl logs -n tenant1-ns1 ping-00001-deployment-76b69b869c-k4p5g user-container 
2022/07/05 18:45:07 target:  http://pong.tenant1-ns1
2022/07/05 18:45:07 ping succeeded
2022/07/05 18:45:09 ping succeeded
2022/07/05 18:45:11 ping succeeded
2022/07/05 18:45:13 ping succeeded
2022/07/05 18:45:15 ping succeeded
2022/07/05 18:45:17 ping succeeded
```

In the same namespace (tenant1-ns1), `ping-ns2` sends a ping to `pong` in the `tenant1-ns2` namespace, belonging to the same tenant:

```shell
$ kubectl logs ping-ns2-00001-deployment-6bfc86484c-67z8z user-container 
2022/07/05 18:46:38 target:  http://pong.tenant1-ns2
2022/07/05 18:46:38 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:46:40 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:46:42 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:46:44 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:46:46 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:46:48 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:46:50 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:46:52 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:46:54 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:46:56 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:46:58 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:47:00 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:47:02 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:47:04 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:47:06 ping failed: Get "http://pong.tenant1-ns2": dial tcp: lookup pong.tenant1-ns2 on 10.96.0.10:53: no such host
2022/07/05 18:47:08 ping succeeded
2022/07/05 18:47:10 ping succeeded
2022/07/05 18:47:12 ping succeeded
```

Finally, in the same namespace, `ping-tenant2-ns1-fail` tries to ping tenant2 ns1 pong pod, but the traffic is blocked, as expected:

```shell
$ kubectl logs -n tenant1-ns1 ping-tenant2-ns1-fail-00001-deployment-66879c89cf-qnrvr user-container
2022/07/05 18:50:05 target:  http://pong.tenant2-ns1
2022/07/05 18:50:07 ping failed: Get "http://pong.tenant2-ns1": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
2022/07/05 18:50:11 ping failed: Get "http://pong.tenant2-ns1": dial tcp 10.96.16.135:80: i/o timeout (Client.Timeout exceeded while awaiting headers)
2022/07/05 18:50:15 ping failed: Get "http://pong.tenant2-ns1": dial tcp 10.96.16.135:80: i/o timeout (Client.Timeout exceeded while awaiting headers)
2022/07/05 18:50:19 ping failed: Get "http://pong.tenant2-ns1": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
2022/07/05 18:50:23 ping failed: Get "http://pong.tenant2-ns1": context deadline exceeded (Client.Timeout exceeded while awaiting headers)

```


## TODOs

- Restrict kourier controller RBAC to tenant namespaces
- Allow access to metrics
- Non-activator path
