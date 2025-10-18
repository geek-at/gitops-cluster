# Gitops Cluster repo

Check out my [blog post](https://blog.haschek.at/2025/ultimate-gitops-raspberry-pi-cluster.html) on info how to use this in a Docker swarm cluster

## Using the autodeploy.sh script

It makes most sense to run it in a cronjob every few minutes. Since it's doing only a git fetch it's minimal on bandwidth but this way you don't need to configure any webhooks. Works best with locally hosted git instances

```cron
*       *       *       *       *       /path/to/your/autodeploy.sh
```