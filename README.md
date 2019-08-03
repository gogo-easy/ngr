# NgRouter
NgRouter是基于OpenResty的强大的边缘网关中间件。

## 架构模块
1. NgRouter Gateway: 用于网关服务节点
2. NgRouter Admin：用于配置管理API服务
3. 架构图

## 代码结构
### 启动模块，负责编写NgRouter命令，动态生成配置,Gateway Service及Admin Service的启动都依赖与带模块
- bin：启动和关闭命令模块
- conf：配置模块

### core核心逻辑模块
- cache: 缓存访问层公共逻辑模块
- dao：数据访问模块 
- framework： 基础框架层模块
- store：数据存储模块
- utils: 工具集 

### plugins: API控制插件模块
### lualib：引入并改造lua公用库
### admin-api：API网关Admin模块Restful API定义
### lor: lor框架引入，用于实现admin-api接口暴露

## 依赖
- [OpenResty](http://openresty.org/cn/)

NgRouter运行在Openresty的基础之上。

- [luafilesystem](http://keplerproject.github.io/luafilesystem/)

NgRouter bin模块的文件系统操作工具库

- [redis](https://redis.io/)

NgRouter部分模块使用redis做临时缓存和计数等功能

- [mysql](https://www.mysql.com/)

支持化NgRouter核心配置


## 贡献者
- [@Fijian](https://github.com/jacobslei)
- [@yearyeardiff](https://github.com/yearyeardiff)


## Wiki
[分布式API网关中间件—NgRouter](https://github.com/gogo-easy/ngr/wiki)

## NgRouter程序安装及运行
- [安装](https://github.com/gogo-easy/ngr/wiki/NgRouter%E5%AE%89%E8%A3%85%E8%AF%B4%E6%98%8E)
- [运行](https://github.com/gogo-easy/ngr/wiki/%E8%BF%90%E8%A1%8CNgRouter)

## License
[MIT](./LICENSE)
