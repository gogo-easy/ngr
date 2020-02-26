[![][ngr-logo]][ngr-url]

# NgRouter - A Pratical API Gateway

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/gogo-easy/ngr/blob/master/LICENSE) [![Version](https://img.shields.io/github/v/release/gogo-easy/ngr)](https://github.com/gogo-easy/ngr/releases)

NgRouter是基于OpenResty开发的API网关，继承了Nginx的高并发、低延迟的强大性能的同时，也提供诸如认证鉴权、限流、熔断、健康检查、动态上游发现等常用功能。通过集群化横向扩展多实例的部署方式，可作为企业级边缘网关承载百万级并发，也可根据环境的逻辑划分，每个逻辑单元部署一套，用于需要多环境管理的场景。



NgRouter is an enterprise-class API gateway based on Openresty. Compared to Openresty, it has almostly the same performance of high concurrency and low latency, it also has a lot of common practical functions such as authentication of requests, dynamically upstream lists, health check, rate limiting, fault torlerance,  etc. NgRouter can be deployed in single -node mode (usually for experiment), and can be scaled to multi-cluster mode, each cluster is dedicated for a logical environment. This makes it very suitable for the cases of multi-environment.

更多关于NgRouter的详细介绍请参见:[GITHUB WIKI](https://github.com/gogo-easy/ngr/wiki) | [码云文档](https://gitee.com/fijian/ngr/wikis/Home)

## 架构图

![arch](./logo/arch.png)

### 组件

- NGR-Gateway：NGR网关，属于逻辑概念，由多个NgRouter实例组成集群，实际流量由NgRouter实例处理
- NgRouter：NgRouter Gateway实例，承载业务流量，根据路由规则、插件功能，完成业务流量的访问代理
- Log-Redis：存储一些如错误日志，静态指标，数据模版等非核心信息，全局唯一，支持standalone和sentinel部署模式，NgRouter Gateway对其依赖为弱依赖
- Config-DB：MySQL提供的配置持久化服务，全局唯一，存储网关的配置信息，如主机配置、路由配置、插件配置等，建议搭建Master-Slave HA模式，NgRouter Gateway对其依赖为弱依赖
- NGR-Admin：NgRouter Gateway的管理API端，以统一化的方式管理多个NGR-Gateway集群。提供RESTFUL API方式可与其他运维系统进行对接，例如风控系统，弹性伸缩容系统
- NGR-Portal：多网关集群的图形化管理portal，详见NgrAdminPortal项目([GITHUB Location](https://github.com/gogo-easy/ngrAdminPortal)|[码云项目地址](https://gitee.com/fijian/ngrAdminPortal))

### 架构说明

**管理架构**

NGR网关一般以集群方式部署，一个NGR网关由多个NgRouter实例组成。全局可以有多组NGR网关，即多个NgRouter集群。但所有NGR网关由全局唯一的一个NGR-Admin来管理，并向外暴露具有管理功能的API接口。通过管理接口，响应管理请求，从全局Config-DB中读取或写入网关配置，实现中心化的管理。出于管理端安全性的考虑，管理接口需通过BasicAuth方式认证访问。面向网关管理人员，[Spring Future ](https://github.com/gogo-easy)团队默认提供一个[NGR-Portal](https://github.com/gogo-easy/ngrAdminPortal)作为NGR-Admin的图形化管理portal，提供网关配置的增删改查操作。其他使用本项目的第三方组织也可以根据API文档自行开发第三方管理工具。

**工作机制**

每个网关实例周期性向NGR-Admin发送心跳信息，NGR-Admin根据收到的心跳包，判定NgRouter的状态。默认心跳周期为15s。相同网关集群中的所有NGR-Gateway实例周期性拉取Config-DB中属于本网关的配置，并动态加载至内存中，默认配置加载周期为10s。每个NgRouter具备一个metrics模块，负责记录、统计处理信息及性能指标，Log-Redis用于缓存metrics信息。

## 管理页面截图

![preview](./logo/preview.png)

## Feature

- **统一管理界面**

  NgRouter提供了统一的管理页面集中管理不通的网关集群（NgRouter Gateway cluster），不同网关集群配置隔离，同一网关集群内的网关实例共享本集群的配置

- **配置修改实时生效**

  在管理页面对集群配置修改后，实时推送该集群的所有网关实例，立即生效

- **支持插件管理**

  NgRouter的功能以插件化的形式自由组合，实现热插拔。自带一部分基本功能性插件，每个插件实现不同功能，如认证鉴权、限流等。考虑到企业和环境差异造成的功能需求的差异，NgRouter也支持通过编写自定义插件的方式实现特殊的客制化需求。通过管理端中的“插件管理”，可由用户自行选择插件启停及优先级

- **动态上游发现**

  网关支持upstream的服务注册发现，动态更新上游节点列表而无需重启服务，降低了网关的运维复杂度

  支持多种负载均衡策略，如weighted round-robin, ip_hash等 

- **服务治理能力**

  提供上游服务治理能力，如：基于请求特征的限流、熔断等

- **健康检查**

  可对上游服务进行主动或被动健康检查，发现并剔除不可用服务

- **安全性**

  支持ACL，基于IP的黑白名单，SQL注入攻击拦截

- **CLI工具**

  提供CLI工具集管理网关集群

- **REST API接口**

  提供REST API接口操作网关集群

- **性能统计**

  提供实时性能监控渠道，默认集成statsd，prometheus等监控体系，统计指标包括：QPS、响应时间、成功率等

- **日志**

  支持多种日志功能，如本地日志、syslog、ELK
  
## How to use

- 管理控制台使用说明文档见 [GITHUB](https://github.com/gogo-easy/ngrAdminPortal/wiki/Using-Guide) | [码云](https://gitee.com/fijian/ngrAdminPortal/wikis/Using-Guide?sort_id=1840263)

## Installation

- [Quick Start](./Quick%20Start.md)

## Release

- [版本发布](https://github.com/gogo-easy/ngr/releases)

## Document

- [GITHUB WIKI](https://github.com/gogo-easy/ngr/wiki)
- [码云文档](https://gitee.com/fijian/ngr/wikis/Home)

## Developer

- [@SpringFuture](https://github.com/gogo-easy)

## License

The project is licensed by [Apache 2.0](https://github.com/gogo-easy/ngr/blob/master/LICENSE)

## Contact Us
<table border="0">
    <tr>
        <td>微信交流群：微信群(加微信入群)</td>
    </tr>
    <tr>&nbsp;</tr>
    <tr>
        <td><img title="微信交流群" src="./logo/chat-jacobs.png" height="200" width="220"/></td>
    </tr>
</table>

## 管理控制台项目

[GITHUB Location](https://github.com/gogo-easy/ngrAdminPortal) | [码云地址](https://gitee.com/fijian/ngrAdminPortal)


[ngr-logo]: ./logo/hoot1.png
[ngr-url]: https://github.com/gogo-easy/ngr
