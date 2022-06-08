# Multiple Namespaces per Tenant Knative with Kourier Setup

This setup is similar to the [Multiple Namespaces per Tenant Pod Setup](../tenant-multiple-namespaces-svc)
using Knative Services instead of pods.

The Knative network layer is Kourier with this [PR](https://github.com/knative-sandbox/net-kourier/pull/852).

## Installing

Start a kind cluster with the Calico CNI plugin and Knative Serving:

```shell
$ ./hack/setup-kind-with-kn.sh
```

Then clone `net-kourier` and check out the patched Kourier (the easiest way is to use
the [GitHub CLI](https://cli.github.com)):

```shell
$ gh pr checkout 852
```

And deploy:

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

## Admin tasks

### Creating a new tenant namespace

#### Annotations

Create a namespace and then add these 3 annotations:

- `kourier.knative.dev/listener`: the envoy listener suffix to use
- `kourier.knative.dev/listener-port`: the envoy listener port
- `kourier.knative.dev/listener-tls-port`: : the envoy listener TLS port

There can be multiple namespaces sharing the same annotation values. 
However for a given listener, all ports must be the same. 
Kourier does not check the provided values are valid and consistent (yet), so be careful.

#### Envoy Service

The first time you declare a new listener, you also need to create a Kubernetes service
in `kourier-system`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kourier-internal-<listener>
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
    - name: https
      port: 443
      protocol: TCP
      targetPort: <listener-tls-port>
  selector:
    app: 3scale-kourier-gateway
  type: ClusterIP
```

#### Network Policies

Tenants are isolated (i.e. private services from tenantX are not accessible from tenantY) by applying these network
policies in each namespace:

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

NOTE: for clarity, not all request paths are shown in this diagram.



## TODOs

- Restrict kourier controller RBAC to tenant namespaces
- Allow access to metrics
- Non-activator path
