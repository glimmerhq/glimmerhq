# glimmer

Yet another Git development platform. Forked from GitLab CE.

**THIS PROJECT IS NOT YET READY!!! I needed to add something so GH would stop bugging me.** 

## Open source software to collaborate on code

- Manage Git repositories with fine grained access controls that keep your code secure
- Perform code reviews and enhance collaboration with merge requests
- Complete continuous integration (CI) and continuous deployment/delivery (CD) pipelines to build, test, and deploy your applications
- Each project can also have an issue tracker, issue board, and a wiki
- Completely free and open source (MIT Expat license)

## Licensing

See the [LICENSE](LICENSE) file for licensing information as it pertains to
files in this repository.

## Requirements

Please see the [requirements documentation](doc/install/requirements.md) for system requirements and more information about the supported operating systems.

## Contributing

glimmer is an open source project and we are very happy to accept community contributions. Please refer to [Contributing to glimmer page](https://about.glimmerhq.com/contributing/) for more details.

## Install a development environment

To work on glimmer itself, we recommend setting up your development environment with [the glimmer Development Kit](https://github.com/glimmerhq/glimmer-development-kit).
If you do not use the glimmer Development Kit you need to install and setup all the dependencies yourself, this is a lot of work and error prone.
One small thing you also have to do when installing it yourself is to copy the example development Unicorn configuration file:

    cp config/unicorn.rb.example.development config/unicorn.rb

Instructions on how to start glimmer and how to run the tests can be found in the [getting started section of the glimmer Development Kit](https://github.com/glimmerhq/glimmer-development-kit#getting-started).

## Software stack

glimmer is a Ruby on Rails application that runs on the following software:

- Ubuntu/Debian/CentOS/RHEL/OpenSUSE
- Ruby (MRI) 2.7.2
- Git 2.24+
- Redis 4.0+
- PostgreSQL 11+

## UX design

Please adhere to the [UX Guide](doc/development/ux_guide/index.md) when creating designs and implementing code.

## Why?

[Read here](https://about.glimmerhq.com/why/)

## Is it any good?

[Yes](https://about.glimmerhq.com/is-it-any-good/)
