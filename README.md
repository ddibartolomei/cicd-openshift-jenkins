# CI/CD on Openshift with Jenkins

 This document describes the setup steps and execution instructions for the setup scripts and Jenkins pipelines defining the CI/CD automation of applications deployed on Red Hat Openshift Container Platform v4.x (shortly OCP) using Quay image registry v3.3.x. The scripts and pipelines are centered on the deployment of applications running on Red Hat JBoss EAP v7.x, but can be modified to support also other kinds of deployments, for example on Apache Tomcat: the main structure of the flow and implementations remains the same.

 So far, the pipelines have been defined to support the deployment to the *development* environment, *test* environment and image promotion from the *development* Quay instance to the *test* Quay instance.


## Prerequisites
In order to execute the CI/CD pipelines the following command line tools must be available in the Jenkins running environment:
- Maven 3.x (inside the *Manage Jenkins > Global Tool Configuration* section, setup a Maven installation named "*M3*")
- OC client for the same version as the target OCP clusters
- Skopeo to copy images between image registries

The pipelines and scripts of this projects have been tested on:
- Red Hat Openshift Container Platform v4.4
- Red Hat Quay v3.3.1
- Jenkins v2.235.2
- Maven v3.5.3
- OC client v4.4
- Skopeo v1.1.1

Be sure that the Quay instance for each Openshift cluster is listed among the insecure registries of the cluster itself (edit *image.config.openshift.io/cluster* and check that the Quay host is in the *insecureRegistries* list).

## Jenkins pipelines setup

### Base common pipelines

Define a folder named `base-pipeline` in the root of Jenkins pipelines.

Inside the folder create the following 3 items of type *Pipeline* named as follows:
1. `dev-deployment`, to generically compile and build the artifact using Maven, create the image build using the an Openshift build config, execute the application configuration update on OCP and the deployment config rollout, for a *development* environment;
2. `test-deployment`, to generically execute the application configuration update on OCP and the deployment config rollout, for a *test* environment;
3. `image-promotion`, to generically execute the image promotion/copy from a Quay registry instance (e.g. the one of the *development* environment) to another one (e.g. the one of the *test* environment).

For each of these pipelines put the content of the relative *pipeline/base-pipeline/Jenkinsfile.\<pipeline-name\>* in the *Pipeline script definition* section of the pipeline configuration form on Jenkins.

Furthermore, in order to make Jenkins aware that these pipelines declare their parameters in the script itself, run them once and stop the running job almost immediately: Jenkins will then recognize and add the parameters, letting the user start the pipelines, showing the form to set input parameters.

### Application pipelines

Define in the root of Jenkins pipeline list these 3 pipelines for each application to deploy, named as follows:
1. `<app-name>-dev-deployment`
2. `<app-name>-test-deployment`
3. `<app-name>-dev-to-test-image-promotion`

The `<appname>` placeholder is the name of the application (e.g. *myapp*).

The Jenkinsfiles in the directory *pipeline* named *Jenkinsfile.app-** must be considered as templates for application specific pipelines. 

For each of the new application specific pipelines define above, put the content of the relative template file *pipeline/Jenkinsfile.app-** in the *Pipeline script definition* section of the pipeline configuration form on Jenkins, setting placeholder values as required.

Also for these application pipelines a "start and immediate stop" run is required once in order to make Jenkins aware that the pipelines declare input parameters, as described above for base pipelines.

#### Setting up placeholder values for *\<app-name\>-dev-deployment*

The `<app-name>-dev-deployment` application pipeline invokes the base pipeline *dev-deployment* passing some parameters. The following parameter placeholders must be replaced with the correct values for the specific application and target OCP/Quay environment:

| Placeholder       | Description  | Example values   |
|:------------------|:-------------|:-----------------|
| `<SOURCE_CODE_REPOSITORY_PLACEHOLDER>` | url of the git repository containing the source code | *https://gitlab.com/myproject/myapp.git* |
| `<DEV_ENV_CONFIG_REPOSITORY_PLACEHOLDER>` | url of the git repository containing the app configuration for the *development* environment | *https://gitlab.com/myproject/myapp-config-dev.git* | 
| `<APP_ARTIFACT_NAME_PLACEHOLDER>` | filename of the app artifact | *myapp.war* | 
| `<APP_ARTIFACT_RELATIVE_PATH_PLACEHOLDER>` | relative path to the built artifact in the local working directory of Jenkins | *target*<br>*mysubmodule/target* |
| `<DEV_ENV_OCP_API_URL_PLACEHOLDER>` | api url of OCP for the *development* environment | *https://api.mydevinstance.myocpenv.com:6443* |
| `<DEV_ENV_QUAY_REGISTRY_HOST_PORT_PLACEHOLDER>` | host (and port if required) of Quay for the *development* environment | *quayecosystem-quay-openshift-quay.apps.mydevinstance.myocpenv.com* |
| `<DEV_ENV_OCP_PROJECT_NAMESPACE_PLACEHOLDER>` | target Openshift namespace/project | *myproject* |
| `<DEV_ENV_OCP_APP_NAME_PLACEHOLDER>` | application name on Openshift (note that it must be the same name used for deployment config, build config, config map prefix, image name, etc in the target Openshift namespace) | *myapp* |

The template also pass some other parameters that can be edited if required:
| Parameter       | Description  | Default value   |
|:----------------|:-------------|:----------------|
| `SOURCE_GIT_CREDENTIAL_ID` | id of the Jenkins *Username/Password* credential for the git repository of the source code | *credential-gitlab-repo* |
| `CONFIG_GIT_CREDENTIAL_ID` | id of the Jenkins *Username/Password* credential for the git repository of configuration for the *development* environment | *credential-gitlab-repo* |
| `OCP_SERVICE_TOKEN_CREDENTIAL_ID` | id of the Jenkins *Secret text* credential containing a valid token of the OCP service account used by Jenkins for operations towards the OCP of the *development* environment| *dev-env-ocp-jenkins-service-account-token* |
| `IMAGE_REGISTRY_NAMESPACE_PREFIX` | prefix for the registry namespace (the Quay organization) | *openshift_* (set value to empty string "" to omit the prefix) |

##### Manual invocation
The pipeline can be manually invoked passing a single parameter `SOURCE_BUILD_TAG` containing the tag name to be checked out from the source repository to create the artifact. By convention, the tag name **must have** the following format in order to correlate the source version to the (*development* environment) config version:

`<SOURCE_VERSION>_config<DEV_ENV_CONFIG_VERSION>`

- `<SOURCE_VERSION>` is the version of the source code to build according to the versioning format chosen for the code (e.g. *1.0*, *1.3.2*, etc.);
- `<DEV_ENV_CONFIG_VERSION>` is the version of the configuration to be used for the source code in order to make it work correctly in the *development* environment (e.g. *1.7*, *10.4.2*, etc.). The version of the configuration is the exact name of the tag created on the configuration repository (the value used to replace the `<DEV_ENV_CONFIG_REPOSITORY_PLACEHOLDER>` placeholder as described above).

Examples:
- Tag for the source repository: `1.1_config1.3` (using the tag `1.3` of the *development* environment configuration repository)
- Tag for the source repository: `1.2_config1.4` (using the tag `1.4` of the *development* environment configuration repository)
- Tag for the source repository: `1.0_config1.0` (using the tag `1.0` of the *development* environment configuration repository)

Using this convention, the `SOURCE_BUILD_TAG` parameter is enough for the pipeline to know also the tag name of the configuration repository. 
Furthermore, the source tag and the configuration tag are strongly coupled at the beginning of the CI/CD process in order to avoid potential misalignment of the binary artifact version and the related working configuration version: this build tag is also used to produce the tag (version) of the built image at the end of the deployment into the *development* environment.
In the next environments the configuration is instead specified explicitly.

##### Code block for Gitlab webhook data evaluation
The beginning part of the *\<app-name\>-dev-deployment* pipeline script allows to dynamically populate the `sourceBuildTag` variable. This variable will contain the tag name to be checked out from the source repository to create the artifact and then the build image.
This way, the variable value is taken from the trigger values of a (Gitlab) webhook, if configured and triggered, otherwise from the input parameter (*SOURCE_BUILD_TAG*) if the pipeline is manually started.
Please note that, if the webhook is set up, once a tag is pushed for the source repository, it (almost) immediately triggers the Jenkins pipeline: for this reason, the related tag of the configuration repository **must already have been created and pushed**.

#### Setting up placeholder values for *\<app-name\>-test-deployment*

The `<app-name>-test-deployment` application pipeline invokes the base pipeline *test-deployment* passing some parameters. The following parameter placeholders must be replaced with the correct values for the specific application and target OCP/Quay environment:

| Placeholder       | Description  | Example values   |
|:------------------|:-------------|:-----------------|
| `<TEST_ENV_CONFIG_REPOSITORY_PLACEHOLDER>` | url of the git repository containing the app configuration for the *test* environment (this repository could also contain the configurations of the *production* environment, but the tag names must be different) | *https://gitlab.com/myproject/myapp-config.git* | 
| `<TEST_ENV_OCP_API_URL_PLACEHOLDER>` | api url of OCP for the *test* environment | *https://api.mytestinstance.myocpenv.com:6443* |
| `<TEST_ENV_QUAY_REGISTRY_HOST_PORT_PLACEHOLDER>` | host (and port if required) of Quay for the *test* environment | *quayecosystem-quay-openshift-quay.apps.mytestinstance.myocpenv.com* |
| `<TEST_ENV_OCP_PROJECT_NAMESPACE_PLACEHOLDER>` | target Openshift namespace/project | *myproject* |
| `<TEST_ENV_OCP_APP_NAME_PLACEHOLDER>` | application name on Openshift (note that it must be the same name used for deployment config, config map prefix, image name, etc in the target Openshift namespace) | *myapp* |

Note that, usually, `<TEST_ENV_OCP_PROJECT_NAMESPACE_PLACEHOLDER>` and `<DEV_ENV_OCP_PROJECT_NAMESPACE_PLACEHOLDER>` (of the *\<app-name\>-dev-deployment* pipeline) have the same value. The same applies to `<TEST_ENV_OCP_APP_NAME_PLACEHOLDER>` and `<DEV_ENV_OCP_APP_NAME_PLACEHOLDER>`.

The template also pass some other parameters that can be edited, if required:
| Parameter       | Description  | Default value   |
|:----------------|:-------------|:----------------|
| `CONFIG_GIT_CREDENTIAL_ID` | id of the Jenkins *Username/Password* credential for the git repository of configuration for the *test* environment | *credential-gitlab-repo* |
| `OCP_SERVICE_TOKEN_CREDENTIAL_ID` | id of the Jenkins *Secret text* credential containing a valid token of the OCP service account used by Jenkins for operations towards the OCP of the *test* environment| *test-env-ocp-jenkins-service-account-token* |
| `IMAGE_REGISTRY_NAMESPACE_PREFIX` | prefix for the registry namespace (the Quay organization) | *openshift_* (set value to empty string "" to omit the prefix) |

##### Manual invocation
The pipeline can be manually invoked passing two parameters:
- `IMAGE_TAG` containing the tag of the image used for deployment (e.g. *1.1_config1.2*)
- `CONFIG_TAG` containing the tag to checkout for the *test* environment configuration repository (e.g. *test-1.2*)

#### Setting up placeholder values for *\<app-name\>-dev-to-test-image-promotion*

The `<app-name>-dev-to-test-image-promotion` application pipeline invokes the base pipeline *image-promotion* passing some parameters. The following parameter placeholders must be replaced with the correct values for the specific application and target OCP/Quay environments (*development* and *test*):

| Placeholder       | Description  | Example values   |
|:------------------|:-------------|:-----------------|
| `<APP_IMAGE_NAME_PLACEHOLDER>` | name of the image | *myapp* | 
| `<DEV_ENV_QUAY_REGISTRY_HOST_PORT_PLACEHOLDER>` | host (and port if required) of the source (Quay) registry for the *development* environment | *quayecosystem-quay-openshift-quay.apps.mydevinstance.myocpenv.com* |
| `<DEV_ENV_QUAY_REGISTRY_NAMESPACE_PLACEHOLDER>` | namespace/organization for the source image to be copied | *myproject* |
| `<TEST_ENV_QUAY_REGISTRY_HOST_PORT_PLACEHOLDER>` | host (and port if required) of the target (Quay) registry for the *test* environment | *quayecosystem-quay-openshift-quay.apps.mytestinstance.myocpenv.com* |
| `<TEST_ENV_QUAY_REGISTRY_NAMESPACE_PLACEHOLDER>` | namespace/organization for the target image to be copied | *myproject* |

Note that, usually, `<DEV_ENV_QUAY_REGISTRY_NAMESPACE_PLACEHOLDER>` and `<TEST_ENV_QUAY_REGISTRY_NAMESPACE_PLACEHOLDER>` have the same value.

The template also pass some other parameters that can be edited, if required:
| Parameter       | Description  | Default value   |
|:----------------|:-------------|:----------------|
| `SOURCE_IMAGE_REGISTRY_CREDENTIAL_ID` | id of the *Username/Password* credential for the source Quay registry | *dev-env-quay-user-pw* |
| `SOURCE_IMAGE_REGISTRY_NAMESPACE_PREFIX` | prefix for the source registry namespace (the Quay organization) | *openshift_* (set value to empty string "" to omit the prefix) |
| `TARGET_IMAGE_REGISTRY_CREDENTIAL_ID` | id of the *Username/Password* credential for the target Quay registry | *test-env-quay-user-pw* |
| `TARGET_IMAGE_REGISTRY_NAMESPACE_PREFIX` | prefix for the target registry namespace (the Quay organization) | *openshift_* (set value to empty string "" to omit the prefix) |

Note that, usually, if a prefix is given, `<SOURCE_IMAGE_REGISTRY_NAMESPACE_PREFIX>` and `<TARGET_IMAGE_REGISTRY_NAMESPACE_PREFIX>` have the same value.

##### Manual invocation
The pipeline can be manually invoked passing the parameter `IMAGE_TAG` containing the tag of the image to be copied from the Quay instance of the *development* environment to the one of the *test* environment (e.g. *1.1_config1.2*)


## Scripts to setup Openshift namespaces and resources

### Script *setup-jenkins-service-account*
The script named `setup-jenkins-service-account.sh` creates a namespace on OCP and a service account (for Jenkins), with the same name, inside it. Then it generates a token for the service account. This token must be configured on Jenkins and is used for each operation executed towards OCP by the OC client.

The script takes 3 parameters:
```
$ ./setup-jenkins-service-account.sh <jenkins-service-account-name> <ocp-api-url> <ocp-admin-token>
```
The `<jenkins-service-account-name>` parameter is the name of the service account used by Jenkins, but also the namespace to be created, holding this service account (e.g. *jenkins*).
The `<ocp-admin-token>` parameter must be a valid token of an OCP user (probably an OCP Administrator) with privileges to create namespaces.

Usage example:

```
$ ./setup-jenkins-service-account.sh jenkins https://api.openshiftcluster.company.com:6443 abcedf-dasdi31231-dasfaf
```
In this example the namespace and the service account will be both called *jenkins*.

Take note of the generated token at the end of the script execution: it must be used as value for the credentials named *dev-env-ocp-jenkins-service-account-token* and *test-env-ocp-jenkins-service-account-token* depending on the OCP cluster it has been created on.

### Script *setup-project*
The script named `setup-project.sh` creates a namespace on OCP for an application project, grants the *edit* role on the namespace to the Jenkins service account and adds the Quay secret, linking it to the *builder* and *default* service accounts of the namespace in order to write built images on Quay and retrieve them on pod startup.

The script takes 5 parameters:
```
$ ./setup-project.sh <target-namespace> <jenkins-service-account-name> <quay-pull-secret-yaml-file> <ocp-api-url> <ocp-admin-token>
```

The `<target-namespace>` parameter is the namespace to be created.
The `<jenkins-service-account-name>` parameter is the name of the service account used by Jenkins (created with the *setup-jenkins-service-account* script)
The `<quay-pull-secret-yaml-file>` parameter is the relative path/file to the yaml file containing the Quay push/pull secret (refer to the section [Generate Quay pull/push secrets](#generate-quay-pull-and-push-secrets) for details about creating this file).
The `<ocp-admin-token>` parameter must be a valid token of an OCP user (probably an OCP Administrator) with privileges to create namespaces.

Usage example:

```
$ ./setup-project.sh my-project jenkins quay/quay-pull-secret.yaml https://api.openshiftcluster.company.com:6443 abcedf-dasdi31231-dasfaf
```

### Script *setup-app*
The script named `setup-app.sh` creates an application, based on the *RH JBoss EAP v7.2* base image (*jboss-eap72-openshift:1.1*), inside the OCP namespace created for the application project, applies a patch to the related deployment config to disable automatic rollout triggers on image/config change, exposes the app creating a route, creates and binds to the app a config map and a secret, creates the liveness and readiness probes.

The script takes 6 parameters:
```
$ ./setup-app.sh <environment-type> <target-namespace> <app-name> <config-map-mount-absolute-dir> <ocp-api-url> <ocp-service-token>
```

The `<environment-type>` parameter can be:
- `dev`, for the *development* environment, where an image build is executed to create the image to run the application
- any other string, for environments where no image build is executed because an existing image is deployed (copied from the registry of the *development* environment) - e.g.: `test`, `prod`, ...

The `<target-namespace>` parameter is the namespace to create the app and related resources into.
The `<app-name>` parameter is the name of the application to be created (the app related resources, like deployment config, build config, etc. will have the same name).
The `<config-map-mount-absolute-dir>` parameter is the absolute path where the config map (named `<app-name>-config`) will be mounted.
The `<ocp-service-token>` parameter must be a valid token of a service account with privileges to create the resources (it could also be a token of a normal user with privileges on the namespace).

In the local directory where the script is executed there must exist an empty directory named "config". The config map is created based on this directory, just to bind it to the deployment config once for all.

In the local directory where the script is executed there must exist a directory named "*secret*" containing a file named *config-data-secret.yaml*. This file defines a secret named `<app-name>-config-data` with just a dummy key/value. This secret is created just to bind it to the deployment config once for all.

The secret and the config map are created by this script and replaced/updated by the pipelines, every time they are run, using the values/files from the configuration git repositories.

Usage example:

```
$ ./setup-app.sh dev my-project my-app /opt/configurazioni/config https://api.openshiftcluster.company.com:6443 VALID-TOKEN
```

### Script *cleanup-project*
The script named `cleanup-project.sh` completely deletes a namespace on OCP. This is just an utility script.

The script takes 3 parameters:
```
$ ./cleanup-project.sh <target-namespace> <ocp-api-url> <ocp-admin-token>
```

The `<target-namespace>` parameter is the namespace to be deleted.
The `<ocp-admin-token>` parameter must be a valid token of an OCP user (probably an OCP Administrator) with privileges to delete namespaces.

Usage example:

```
$ ./cleanup-project.sh my-project https://api.openshiftcluster.company.com:6443 abcedf-dasdi31231-dasfaf
```

### Script *cleanup-app*
The script named `cleanup-app.sh` completely deletes an app (and its resources, like deployment config, build config, config map, secret, etc.). This is just an utility script.

The script takes 4 parameters:
```
$ ./cleanup-app.sh <target-namespace> <app-name> <ocp-api-url> <ocp-admin-token>
```

The `<target-namespace>` parameter is the namespace of the app.
The `<app-name>` parameter is the name of the application to be deleted.
The `<ocp-admin-token>` parameter must be a valid token of an OCP user (probably an OCP Administrator) with privileges to delete resources in the target namespace.

Usage example:

```
$ ./cleanup-app.sh my-project my-app https://api.openshiftcluster.company.com:6443 abcedf-dasdi31231-dasfaf
```

## Setup required credentials on Jenkins
Some credentials values must be set on Jenkins to access OCP, Quay and Gitlab in authenticated mode.

Jenkins credentials are set in the *Manage Jenkins > Manage Credentials* section, creating new entries, for example under the *Jenkins Store* that has a global scope by default.

### Gitlab
Create a credential with *Username with password* type and set the ID field to *credential-gitlab-repo* (if a different id is set, remember to change it also inside the application pipeline definitions).
Add in the right fields the username and password of a Gitlab user that has the required privileges for the repositories the pipelines work on.

### OCP Service account for Jenkins
Create a credential with *Secret text* type and set the ID field to *dev-env-ocp-jenkins-service-account-token* (if a different id is set, remember to change it also inside the application pipeline definitions).
Add in the *Secret* field the service account token obtained at the end of the `setup-jenkins-service-account.sh` script execution for the *development* environment.

In the same way, for the *test* environment, create a credential with *Secret text* type, setting the ID field to *test-env-ocp-jenkins-service-account-token* and the *Secret* field to the service account token generated for the *test* environment.

### Quay
An encrypted password can be generated for the Quay user that will be used for the operations performed by Skopeo tool (copy of images from one Quay instance to another).

#### Generating a quay user encrypted password
For each Quay instance (e.g. *development*, *test* environment), in the Quay web dashboard, login with the user that is going to be used by Jenkins (running Skopeo), go in the *Account Settings* section of the user (in the top-right corner click on the user to show the logged in user menu).
Click on *Generate Encrypted Password* (insert the user password when asked for it) and then copy the encrypted password value from the second field shown.

#### Create the Jenkins credential
Create a credential with *Username with password* type and set the ID field to *dev-env-quay-user-pw* (if a different id is set, remember to change it also inside the application pipeline definitions).
Add in the right fields the username and encrypted password obtained from the previous step.

In the same way, for the *test* environment, create a credential with *Username with password* type, setting the ID field to *test-env-quay-user-pw* and *Username*/*Password* fields to the user/encrypted password generated for the Quay instance of this environment.

#### Generate Quay pull and push secrets
For each Quay instance a push/pull secret must be generated and added into the namespace of each project/application on OCP. The yaml file containing the secret is "installed" using the script named `setup-project.sh`.

In order to generate the yaml file, for each Quay instance, in the Quay web dashboard, login with the user that is going to be used by OCP, go in the *Account Settings* section of the user, then click on *Generate Encrypted Password* (insert the user password when asked for it), click on *Kubernetes Secret* in the menu bar on the left and then click on *Download quay-secret.yml* to download the file.

Use it when creating the project/namespace for the application on OCP, launching the `setup-project.sh` script.

## Structure of git repositories
Each application requires 3 git repositories:

1. The source code repository, containing the code to build using Maven in order to generate the artifact (war, ear, etc.). The root of the repository must contain the `pom.xml` file.
If the code is organized in modules, the Jenkins pipeline expects a parent pom file exists in the root of the repository, referring all the required submodules. The application pipeline allows to define the relative path where the final built artifact will be found.
2. The *development* configuration repository for the *development* environment, containing:
   - in a directory named `s2i`, the files required to create and customize the build image created in the "*Bake*" stage of the *development* pipeline (e.g. custom JBoss EAP configuration file *standalone-openshift.xml*, database driver module, etc.);
   - in the path named `svil/config`, the files (if any) with data/configuration files that must be external to the applicaton image, mapped to the application by a config map (created by the `setup-app.sh` script)
   - in the path named `svil/secret`, the `config-data-secret.yaml` file mapped to the application (using the `setup-app.sh` script), holding application data, mainly "secret" data (but not only, if needed)
3. The configuration repository for *test*, *production* and any other environment different from the *development* one, containing the same file structure of the *development* configuration repository except for the `s2i` directory (this is not required because the image has been already built for the *development* environment and copied as-is to the next environments)

Example of structure for the *development* configuration repository:
```
s2i
    configuration
        standalone-openshift.xml
    modules
        com
            ibm
                db2
                    main
                        db2jcc.jar
                        db2jcc4.jar
                        db2jcc_license_cisuz.jar
                        db2jcc_license_cu.jar
                        module.xml
svil
    config
        DatiConguagli.properties
    secret
        config-data-secret.yaml
```

The `svil` directory name is defined by a convention and it must be equal to the value of the `envId` variable at the beginning of the *Jenkinsfile.dev-deployment* base pipeline script. If a different name is required it must be changed in this base pipeline and in all the *development* configuration repositories.

Example of structure for the *test* (and *production*) configuration repository:
```
coll
    config
        DatiConguagli.properties
    secret
        config-data-secret.yaml
prod
    config
        DatiConguagli.properties
    secret
        config-data-secret.yaml
```

The `coll` and `prod` directory names, as described above for the `svil` directory, are defined by a convention and they must be equal to the value of the *envId* variable at the beginning of the *Jenkinsfile.test-deployment* base pipeline script (or the *production* base pipeline). If a different name is required it must be changed in these base pipelines and in all the *test*/*production* configuration repositories.

Configurations of *non-development* environments are stored in a different git repository because the configuration data for these environments are usually managed by IT teams/people different from developers and the latters should never know the secret configuration data (e.g. credentials) for a test or production environment.

As a best practice, all the configurations external to the application image must contain only data that (could) change between the environments: data that are identical for all of the environments must be inside the files that are contained in the build image of the application.

Also consider, as a good practice, the following naming convention for the 3 repositories:
- `<app-name>` for the source code repository;
- `<app-name>-config-svil` for the *development* configuration repository (or any other defined environment-id for *development* instead of "*svil*");
- `<app-name>-config` for the *test*/*production* configuration repository.

### Non-development repository tagging rules
For *test* and *production* configuration repository the tag names must follow a conventional pattern to avoid conflicting version numbers for the environments: 
- for tags related to *test* environment configuration the pattern could be `coll-<version>`
- for tags related to *prod* environment configuration the pattern could be `prod-<version>`

As described above, the strings "coll" and "prod" are a convention but can be changed (globally) if required. It could be a good practice to keep the version numbers for tags of *test* and *production* configurations aligned to the tag version numbers of configuration changes in the *development* environment configuration repository. The following example clarify the concept:
- if the source code has the tag *1.1_config1.4*, as previously described, it requires a tag named *1.4* in the *development* configuration repository, in order to execute the development deployment pipeline and make the application work;
- then the image tagged with tag *1.1_config1.4* is promoted to the *test* environment Quay registry;
- in order to deploy that image to the *test* OCP, the same set of changes applied to the *development* configuration repository for the tag *1.4* must be replicated (with the required differences) in the *test* configuration repository. These changes could be tagged using the same version number, so using *coll-1.4* as tag name;

This approach is not mandatory but suggested to keep configuration versioning easier.
 

## Setup the Gitlab webhook
The Gitlab plugin (**named *Gitlab*, not *Gitlab webhook***) must be installed on Jenkins (from *Manage Jenkins > Manage Plugins* menu).

On Jenkins:
- in the configuration of the application pipeline `<app-name>-dev-deployment` select the checkbox on "Build when a change is pushed to GitLab".
- the *GitLab webhook URL* is shown on the side (e.g. http://jenkins.mycompany.com/project/my-app-dev-deployment)
- don't change any default configuration value.
- at the end of the webhook section click on the *Generate* button to create a *Secret token*.

On Gitlab (note that Gitlab must be configured to reach external endpoints, Jenkins host in particular):
- in the source code repository select *Settings > Webhooks* in the menu on the left
- set the *GitLab webhook URL* and the *Secret token* and check only *Tag push events* checkbox (**uncheck *Push events***)
- click on *Add webhook* and test it to verify it can work


## Full example to setup and run pipelines
Here is described a full example for a new application: OCP resources setup, application pipeline setup, Quay organization setup, git repository tagging, pipelines invocations.

Requirements:
- the application is named *my-app*
- the project containing the application on OCP is named *my-project*
- the base pipelines have been already created on Jenkins
- Quay credentials and Gitlab repository credentials have been already set on Jenkins

### Setup Jenkins project/service account on OCP
This step is required **only the first time**, for the first application.

Execute:
```
$ ./setup-jenkins-service-account.sh jenkins https://api.openshiftcluster.company.com:6443 <OCP-TOKEN-HERE>
```
The generated Jenkins token must be added to Jenkins credentials as previously described.

The same steps must be executed on the OCP of the *test* environment.

### Setup project and application

Suppose the `quay-pull-secret.yaml` file is in the *quay* directory (the secret is identical for all the applications using the same Quay instance).
A local empty directory named `config` is required.

The `config-data-secret.yaml` file must be created in the *secret* directory with the following content:
```
apiVersion: v1
kind: Secret
metadata:
  name: my-app-config-data
stringData:
  DUMMY: value
```

Note the name of the resource *my-app-config-data*, starting with the application name, as required by the convention.

Execute:
```
$ ./setup-project.sh my-project jenkins quay/quay-pull-secret.yaml https://api.openshiftcluster.company.com:6443 <OCP-TOKEN-HERE>
$ ./setup-app.sh dev my-project my-app /opt/configurazioni/config https://api.openshiftcluster.company.com:6443 <JENKINS-SERVICE-ACCOUNT-TOKEN-HERE-OR-ANY-VALID-TOKEN>
```

The same steps must be executed on the OCP of the *test* environment (remember the *quay-pull-secret.yaml* is different because the Quay instance is different).

### Setup Jenkins
Create the credential on Jenkins for the generated Jenkins service account token (if it is the first time the Jenkins service account is created the on OCP cluster).

Create the application pipelines named as follows, correctly replacing all the placeholders in the templates:
1. `my-app-dev-deployment`
2. `my-app-test-deployment`
3. `my-app-dev-to-test-image-promotion`

### Setup Quay organization
For each Quay instance, in the Quay web dashboard, login with the user that is going to be used by OCP, click on the "+" icon in the upper right corner of the page, select "*New Organization*" and set the name to "*openshift_my-project*" (if the registry namespace prefix configured in the application pipelines is the default *openshift_*).

### Setup git repositories
On Gitlab:
- for the source code repository
  1. create a repository named  `my-app`
  2. populate it with the code
  3. create a tag named *1.0_config1.1*
- for the *development* configuration repository:
  4. create a repository named `my-app-config-svil`.
  5. populate it with files required by the application (`s2i` and `svil` directories).
  6. create a tag named *1.1* (note that "1.0" is not used here just to make the example clear because 1.0 is already used for the source code tag)

### Run dev-deployment pipeline
Manually run the *my-app-dev-deployment* pipeline, setting the value of the `SOURCE_BUILD_TAG` input parameter to *1.0_config1.1*.
Of course this pipeline can be triggered using the tag push operation if the webhook is correctly configured.

Check the execution runs successfully:
1. click on the started job of *my-app-dev-deployment*
2. click *Console Output* in the menu
3. in the console log, click the base pipeline link (e.g. "Starting building: base-pipeline » dev-deployment #1")
4. click *Console Output* in the menu of the base pipeline
5. check the execution log until the end
6. if everything is correctly configured, after the job execution, the application should be running on OCP in a while

### Promoting the image to *test* environment
Run the *my-app-dev-to-test-image-promotion* pipeline, using *1.0_config1.1* as input parameter.

### Setup *test* environment configuration repository
Create the *test* (and *production*) configuration repository naming it *my-app-config*.
Apply, if required, the right changes to it, according to the changes applied on *development* configuration with tag *1.1*.
Tag the repository with a tag name *coll-1.1*

### Run test-deployment pipeline
Manually run the *my-app-test-deployment* pipeline, setting:
- `IMAGE_TAG` parameter to *1.0_config1.1*
- `CONFIG_TAG` parameter to *coll-1.1*

Check the execution runs successfully: if everything is correctly configured, after the job execution, the application should be running on the OCP of the *test* environment in a while.

