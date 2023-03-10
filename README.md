# Primer: a Kubernetes Deployment Hardening

The repository includes:

- A simple Node.js web service backed by a Redis database
- ...run as Kubernetes Deployments and exposed as Services
- A typical Dockerfile to containerize the Node.js app
- [A workflow to build and push the (very large) Node.js-based image to a registry](.github/workflows/build.yaml)
- [A workflow to optimize and _harden_ this image](.github/workflows/harden.yaml)
- [Examples of the input and output images](https://github.com/slim-ai/saas-examples-harden-kubernetes-deployment/pkgs/container/saas-examples-harden-kubernetes-deployment)

Here is a high-level overview of what our Kubernetes manifests intend to do:

<p align="center">
  <img src=https://user-images.githubusercontent.com/45476902/219765099-51d72254-e3d7-4047-886f-dab5c75dfdd6.png width="80%">
</p>

The purpose of this example is to show that hardening of Kubernetes workloads is no harder (no pun intented) than [hardening of regular Docker containers](https://github.com/slim-ai/saas-examples-harden-simple-app).

The application code is straightforward and the Workflow files are heavily commented.

You can explore this repository, and then clone it and adapt it to your application. 

## The Problem and the Solution 

Creating high-quality container images is no easy task. 

How do you choose an optimal base image? How do you configure a multistage build? How do you remove vulnerabilities from your images? One must be a true container expert to get it right. 

However, there is another way.

**Automated Container Image Hardening from Slim.AI**
With Slim.AI, you can: 

* Build an image FROM your favorite base.
* Instrument the image being used in Kubernetes workload with the Slim Sensor.
* Run tests against the Kubernetes workload using instrumented image to collect intelligence about what it needs to run.
* Build a hardened version of the image using that intelligence to use in Kubernetes workload

![Results from Container Image Hardening](https://user-images.githubusercontent.com/45476902/218093055-50a44810-db1a-43fd-a71d-909e521d4a55.png)

## Hardening Kubernetes Workload using the Slim CLI

### Prerequisites

To complete this tutorial, you will need: 

* A fresh version of the Slim CLI installed and configured [link](https://portal.slim.dev/cli) / [docs]()

* A container registry connector configured via the Slim SaaS [link](https://portal.slim.dev/connectors) / [docs](https://www.slim.ai/docs/connectors) 

* A Kubernetes cluster and kubectl configured.

```sh
$ curl -sLS https://get.arkade.dev | sudo sh

$ ark get kind kubectl
$ sudo ln -s ${HOME}/.arkade/bin/kind /usr/local/bin/
$ sudo ln -s ${HOME}/.arkade/bin/kubectl /usr/local/bin/

# [Optional] Start a Kubernetes cluster
$ kind create cluster
```

### What & How

Before we move to the steps, let's see how the flow can be visualized:

![Diagram of the Hardening Process](https://user-images.githubusercontent.com/45476902/218159028-d2b21334-bfeb-45dd-8d2d-725fbe3d3520.png)


#### Step 1: Instrument  ???????

The first step involves instrumenting the image. Simply speaking, this means adding the Slim Sensor to your container so it can act as an intelligence agent to collect data during the `Observe` step.

```sh
$ slim instrument \
  --include-path /service \
  --stop-grace-period 120s \
   ghcr.io/slim-ai/saas-examples-harden-kubernetes-deployment:latest
...
[instrument] target image: ghcr.io/slim-ai/saas-examples-harden-kubernetes-deployment:latest
[instrument] instrumented image: ghcr.io/slim-ai/saas-examples-harden-kubernetes-deployment:latest-slim-instrumented
[instrument] hardened image: ghcr.io/slim-ai/saas-examples-harden-kubernetes-deployment:latest-slim-hardened
...
rknx.2LkF7SjT3M0YbaXAMTjWgGm8zQN  # Instrumentation "attempt ID". Save this: you'll need it later.
```

**NOTE**: Make sure the instrumented image, in our case, `ghcr.io/slim-ai/saas-examples-harden-kubernetes-deployment:latest` is available through the connector.

#### Step 2: Observe (_aka_ "profile" _aka_ "test")  ????

Now that we have our agent (aka, the Slim Sensor) in the target container, it is time to implement the mission. That is, to run a workload (Deployment in this case) using the instrumented image. Make sure you use a specially configured `securityContext` and give the Pods enough time to terminate gracefully: 

```sh
$ export INST_IMAGE=<insert the instrumented image name from the above output>

$ envsubst <  https://raw.githubusercontent.com/slim-ai/saas-examples-harden-kubernetes-deployment/main/kubernetes/app-instrumented.yaml | kubectl apply -f -

$ kubectl apply -f https://raw.githubusercontent.com/slim-ai/saas-examples-harden-kubernetes-deployment/main/kubernetes/redis.yaml 
```

**NOTE:** This is required only for the deployment with instrumented image. Deployment with hardened image won???t need any extra permissions. 

???Test" the deployment with instrumented image ??? the Slim process needs the container to be exercised in some way to trigger the Observations. In the case of this simple app, merely running a `curl` request against the running workload will suffice. In reality, integration tests in a test or staging environment are the most common. 

```sh
$ kubectl port-forward deployment/app 8080:8080 &

$ curl localhost:8080

$ kill %1  # Stops port-forwarding
```

By running curl, we see that the Node web app returns a response. Under the hood, the Slim Sensor observes the running container and collects intelligence about the required libraries, files, and binaries. 

Finally, Stop the Pod(s) gracefully to make the sensor(s) submit the reports back to Slim SaaS. Failure to stop the Pod(s) gracefully may result in a failed hardening process. 

```sh
$ kubectl delete deployment app
```

#### Step 3: Harden  ????

Now that we have the data via automatically submitted reports, we can harden the target image in Deployment, removing unnecessary components and thus reducing the overall vulnerability count and attack surface. 

Harden using the ID obtained on the **Instrument** step:

```sh
$ slim harden --id <instrumentation attempt ID>
```

#### Step 4: Verify  ???

Redeploy the workload with the hardened image (notice that it doesn???t require any extra security context):

```sh
$ export HARD_IMAGE=<insert the hardened image name>

$ envsubst <  https://raw.githubusercontent.com/slim-ai/saas-examples-harden-kubernetes-deployment/main/kubernetes/app-hardened.yaml | kubectl apply -f -

$ kubectl apply -f https://raw.githubusercontent.com/slim-ai/saas-examples-harden-kubernetes-deployment/main/kubernetes/redis.yaml 
```
 
Verify that the hardened image works by re-running tests. 

```sh
$ kubectl get pod -l app=app -o jsonpath={..spec.containers[].image}

$ kubectl port-forward deployment/app 8080:8080 &

$ curl localhost:8080

$ kill %1
```

Cleanup

```sh
$ kubectl delete deployment/app
```

Interested in learning more? Check out our [Solutions page](https://www.slim.ai/solutions). 
