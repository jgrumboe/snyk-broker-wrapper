# RBMH Snyk Broker Jira wrapper

This is a wrapper around the snyk broker (https://github.com/snyk/broker)
and the docker imager snyk/broker:jira.

We need the wrapper to store required tokens into GCP secrets manager.

## Prerequisite

- Review and set some env variables we will need later on
  ```
  export PROJECT=snyk-broker
  export IMAGENAME=snyk-broker-wrapper
  export REGISTRY=eu.gcr.io/$PROJECT
  export REGION=europe-west1
  export SERVICENAME=snyk-broker
  export SERVICEACCOUNT=cr-snyk-broker
  export BROKER_TOKEN=snyk-broker-token
  export JIRA_USERNAME=jira-username
  export JIRA_PASSWORD=jira-password
  export JIRA_HOSTNAME=jira.example.com
  ```

- Create and set a GCP project.
  
  You need to create GCP project first and configure it to the folder you want to.
  Afterwards set it for gcloud cli.
  ```
  gcloud config set project $PROJECT
  ```

- Create a serviceaccount for CloudRun later
  
  ```
  gcloud iam service-accounts create $SERVICEACCOUNT
  ```
  
- Create secrets to hold the token

  ```
  gcloud secrets create snyk-broker-token
  echo -n "$BROKER_TOKEN" | gcloud secrets versions add snyk-broker-token --data-file=-

  gcloud secrets create snyk-broker-jira-password
  echo -n "$JIRA_PASSWORD" | gcloud secrets versions add snyk-broker-jira-password --data-file=-
  ```

- Grant access for the serviceaccount to access the secrets
  
  ```
  gcloud beta secrets add-iam-policy-binding  \
  --member=serviceAccount:$SERVICEACCOUNT@$PROJECT.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor snyk-broker-token

  gcloud beta secrets add-iam-policy-binding  \
  --member=serviceAccount:$SERVICEACCOUNT@$PROJECT.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor snyk-broker-jira-password
  ```

## Build the wrapper container

To be able to push into GCR you need to configure local docker to leverage a `gcloud auth login` first.
```
gcloud auth configure-docker
```

Run the following commands to build and push the container into GCR.
```
docker build . -t $REGISTRY/$IMAGENAME
docker push $REGISTRY/$IMAGENAME
```

## Spin up CloudRun instance

The following command now brings everything together.

```
gcloud beta run deploy $SERVICENAME \
--image=$REGISTRY/$IMAGENAME \
--port=8000 \
--memory=128Mi --cpu=1 \
--min-instances=1 --max-instances=1 \
--platform=managed \
--region=$REGION \
--project=$PROJECT \
--allow-unauthenticated \
--service-account=$SERVICEACCOUNT@$PROJECT.iam.gserviceaccount.com \
--set-env-vars JIRA_USERNAME=$JIRA_USERNAME \
--set-env-vars JIRA_HOSTNAME=$JIRA_HOSTNAME \
--set-env-vars JIRA_PASSWORD_SECRET=$PROJECT/snyk-broker-jira-password \
--set-env-vars BROKER_TOKEN_SECRET=$PROJECT/snyk-broker-token
```

After deployment we get back the URL and need to update our service with the BROKER_CLIENT_URL env var.

```
url=$(gcloud run services describe $SERVICENAME \
--platform=managed --region=$REGION  --format 'value(status.url)')

gcloud run services update $SERVICENAME \
--platform=managed --region=$REGION --update-env-vars BROKER_CLIENT_URL=$url
```

## Cleanup all resources

```
gcloud run services delete $SERVICENAME --quiet
gcloud secrets delete snyk-broker-token --quiet
gcloud secrets delete snyk-broker-jira-password --quiet
gcloud iam service-accounts delete \
   $SERVICEACCOUNT@$PROJECT.iam.gserviceaccount.com --quiet 
gcloud container images delete $REGISTRY/$IMAGENAME --force-delete-tags  --quiet
```
