# ngrAdmin接口说明

端口：7777 （默认）

## 网关实例管理接口

### 接口描述

实例管理接口提供了实例状态查询、实例注册、反注册等功能，主要通过openapi的方式向ngrAdmin portal或运维自动化提供对网关实例的管理能力。

### 协议须知

| 规则     | 描述                         |
| -------- | ---------------------------- |
| 传输方式 | HTTP                         |
| 请求方法 | GET                          |
| 字符编码 | 统一采用UTF-8编码            |
| 响应格式 | 统一采用JSON格式             |
| 接口鉴权 | 签名机制，详情请阅"接口鉴权" |

### 公共参数

无

#### 实例注册接口

##### 接口说明

ngr实例按一定的时间间隔向ngrAdmin节点注册，当ngrAdmin在3倍的注册间隔内未收到某ngr实例的注册信息，则将该实例状态标注为offline状态

##### URL

/instance/register

##### 请求参数

| 参数名称     | 是否必选 | 数据类型 | 数据约束      | 示例数据   | 默认值 | 描述         |
| ------------ | -------- | -------- | ------------- | ---------- | ------ | ------------ |
| gateway_code | 是       | string   | 不可含冒号“:” | my_gateway |        | 网关集群编码 |

##### 响应参数

| 参数名称 | 是否必选 | 数据类型 | 描述         |
| -------- | -------- | -------- | ------------ |
| success  | 是       | bool     | 是否注册成功 |

##### 请求限制

无

##### 参考示例

请求：

```shell
curl -XGET -H "Authorization: Basic YWRtaW46bmdyX2FkbWlu" http://localhost:7777/instance/register
```

注：以上Basic Auth字符串需要替换

响应内容：

```json
{
  "success": true
}
```

#### 实例反注册接口

##### 接口说明

该接口提供了ngr实例的下线功能。使用场景可以是：当运维人员在ngrAdmin portal上看到某个ngr实例offline时，可通过该接口将offline实例从网关集群中删除。

##### URL

/instance/unregister

##### 请求参数

| 参数名称     | 是否必选 | 数据类型 | 数据约束      | 示例数据   | 默认值 | 描述         |
| ------------ | -------- | -------- | ------------- | ---------- | ------ | ------------ |
| gateway_code | 是       | string   | 不可含冒号“:” | my_gateway |        | 网关集群编码 |

##### 响应参数

| 参数名称 | 是否必选 | 数据类型 | 描述         |
| -------- | -------- | -------- | ------------ |
| success  | 是       | bool     | 是否注册成功 |

##### 请求限制

无

##### 参考示例

请求：

```shell
curl -XGET -H "Authorization: Basic YWRtaW46bmdyX2FkbWlu" http://localhost:7777/instance/unregister
```

注：以上Basic Auth字符串需要替换

响应内容：

```json
{
  "success": true
}
```

#### 

## dashboard信息指标接口

### 说明

ngrouter后端存储了多个维度的metrics，如运行状态、实例状态、请求量、请求结果等，便于运维管理人员了解ngrouter的负载，决定是否需要对集群扩容。

### 协议须知

| 规则     | 描述                         |
| -------- | ---------------------------- |
| 传输方式 | HTTP                         |
| 请求方法 | GET                          |
| 字符编码 | 统一采用UTF-8编码            |
| 响应格式 | 统一采用JSON格式             |
| 接口鉴权 | 签名机制，详情请阅"接口鉴权" |

### 公共参数

无

#### 概览接口

##### 接口说明

该接口提供网关集群清单及基础信息，如网关集名、ngr版本、nginx版本、lua版本、启动时间、日志等级、实例明细及状态等

##### URL

/dashboard/show

##### 请求参数

无

##### 响应参数

| 参数名称               | 是否必选 | 数据类型    | 描述                                                         |
| ---------------------- | -------- | ----------- | ------------------------------------------------------------ |
| success                | 是       | bool        | 是否成功返回                                                 |
| msg                    | 是       | string      | 提示信息；当成功反馈时，该字段内容为空；当出错时，该字段提示错误信息 |
| data                   | 否       | object      | 返回数据；当出错时，不含该字段                               |
| +timestamp             | 是       | unix_time   | 当前时间戳                                                   |
| + service_name         | 是       | string      | 集群编码，即集群全局唯一名称                                 |
| ++start_time           | 是       | string      | 集群启动时间                                                 |
| ++ngr_version          | 是       | string      | ngr版本                                                      |
| ++nginx_version        | 是       | string      | nginx版本                                                    |
| ++ngx_lua_version      | 是       | string      | lua版本                                                      |
| ++gateway_status       | 是       | int         | 网关状态，1表示所有实例均online; 0表示有部分实例offline; -1表示所有实例均offline |
| ++ngr_worker           | 是       | int         | 网关实例上的worker数                                         |
| ++error_log_level      | 是       | string      | 日志级别：debug、warn、info、error                           |
| ++instances            | 是       | string      | 网关实例信息                                                 |
| +++is_health           | 是       | bool        | 网关实例是否在线，超过3个注册间隔，则管理节点判定网关实例下线 |
| +++gateway_id          | 是       | int         | 网关集群id                                                   |
| +++address             | 是       | string      | 网关实例地址                                                 |
| +++register_time       | 是       | string      | 首次注册时间                                                 |
| +++renew_time          | 是       | unix_time   | 注册更新时间                                                 |
| ++request_infos        | 是       | object_list | 网关请求统计信息清单                                         |
| +++service_name        | 是       | string      | 网关集群名称                                                 |
| +++total_count         | 是       | int         | 总请求数                                                     |
| +++total_success_count | 是       | int         | 总请求成功数                                                 |
| +++total_request_time  | 是       | int         | 总请求时间                                                   |
| +++request_2xx         | 是       | int         | 返回2xx的请求数                                              |
| +++request_3xx         | 是       | int         | 返回3xx的请求数                                              |
| +++request_4xx         | 是       | int         | 返回4xx的请求数                                              |
| +++request_5xx         | 是       | int         | 返回5xx的请求数                                              |
| +++traffic_read        | 是       | int         | 读流量数                                                     |
| +++traffic_write       | 是       | int         | 写流量数                                                     |

##### 请求限制

无

##### 参考示例

请求：

```shell
curl -XGET -H "Authorization: Basic YWRtaW46bmdyX2FkbWlu" http://localhost:7777/dashboard/show
```

注：以上Basic Auth字符串需要替换

响应内容：

```json
{
	"success": true,
	"data": {
		"base_infos": [{
			"timestamp": 1589885955,
			"instances": [{
				"is_health": true,
				"gateway_id": "1",
				"address": "127.0.0.1",
				"renew_time": "2020-05-19 18:59:07",
				"register_time": "2020-05-10 20:25:28"
			}],
			"service_name": "GatewayService",
			"start_time": "2020-05-19 18:59:07",
			"ngr_version": "1.2.0-pre",
			"nginx_version": "1015008",
			"gateway_status": 1,
			"ngr_worker": "2",
			"ngx_lua_version": "0.10.15",
			"error_log_level": "debug"
		}],
		"request_infos": [{
			"request_5xx": 0,
			"total_success_count": "1",
			"service_name": "GatewayService",
			"traffic_write": 0,
			"total_count": "1",
			"request_3xx": 0,
			"traffic_read": "82",
			"request_2xx": "1",
			"request_4xx": 0,
			"total_request_time": 0
		}]
	}
}
```



#### metric接口

##### 接口说明

该接口提供了基于网关集群维度或虚拟主机维度的metric的查询，metric包括但不限于：总请求数、总请求成功或失败数、总请求字节数等。

##### URL

/dashboard/metrics

##### 请求参数

| 参数名称     | 是否必选 | 数据类型 | 数据约束                   | 示例数据       | 默认值 | 描述                     |
| ------------ | -------- | -------- | -------------------------- | -------------- | ------ | ------------------------ |
| gateway_code | 否       | string   | 不可含冒号“:”              | my_gateway     |        | 网关集群编码             |
| host         | 否       | string   | 不可含冒号、问号           | www.domain.com |        | 虚拟主机名               |
| range        | 否       | int      | 可选值：1，2，4，6，12，24 | 1              | 1      | 查询n小时内的metrics数据 |

##### 响应参数

| 参数名称         | 是否必选 | 数据类型    | 描述                                                         |
| ---------------- | -------- | ----------- | ------------------------------------------------------------ |
| success          | 是       | bool        | 是否成功返回                                                 |
| data             | 是       | object_dict | 返回数据                                                     |
| + ts             | 是       | list        | 时间戳                                                       |
| + host_metrics   | 是       | object_list | 虚机主机级别的指标信息                                       |
| ++metric_name    | 是       | string      | 指标名                                                       |
| ++data           | 是       | float       | 指标名对应的数值                                             |
| ++gateway_host   | 是       | string      | 虚拟主机名；由于虚拟主机在不同网关集群间可能存在重复，因此该字段由{$gateway_code}:{\$host} |
| ++data           | 是       | float       | 指标名对应的数值                                             |
| +gateway_metrics | 是       | object_dict | 网关集群级别的指标信息                                       |
| ++metric_name    | 是       | string      | 指标名                                                       |
| ++gateway_code   | 是       | string      | 虚拟主机名；由于虚拟主机在不同网关集群间可能存在重复，因此该字段由{$gateway_code}:{\$host} |
| ++data           | 是       | list_float  | 指标名对应的数值                                             |

##### 请求限制

无

##### 参考示例

请求：

```shell
curl -XGET -H "Authorization: Basic YWRtaW46bmdyX2FkbWlu" http://localhost:7777/dashboard/metrics
```

注：以上Basic Auth字符串需要替换

响应内容：

```json
{
	"success": true,
	"data": {
		"ts": ["1590125339.101", "1590125399.117", "1590125459.129", "1590125519.143", "1590125579.159", "1590125639.173", "1590125699.189", "1590125759.205", "1590125819.221", "1590125879.234", "1590125939.25", "1590125999.264"],
		"host_metrics": [{
			"data": [null, "1", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"gateway_host": "GatewayService:gateway.local",
			"metric_name": "DASHBOARD_TOTAL_REQUEST_COUNT"
		}, {
			"data": [null, "82", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"gateway_host": "GatewayService:gateway.local",
			"metric_name": "DASHBOARD_TRAFFIC_READ"
		}, {
			"data": [null, "405", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"gateway_host": "GatewayService:gateway.local",
			"metric_name": "DASHBOARD_TOTAL_REQUEST_TIME"
		}, {
			"data": [null, "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"gateway_host": "GatewayService:gateway.local",
			"metric_name": "DASHBOARD_REQUEST_4XX"
		}, {
			"data": [null, "2947", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"gateway_host": "GatewayService:gateway.local",
			"metric_name": "DASHBOARD_TRAFFIC_WRITE"
		}, {
			"data": [null, "1", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"gateway_host": "GatewayService:gateway.local",
			"metric_name": "DASHBOARD_TOTAL_SUCCESS_REQUEST_COUNT"
		}, {
			"data": [null, "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"gateway_host": "GatewayService:gateway.local",
			"metric_name": "DASHBOARD_REQUEST_5XX"
		}, {
			"data": [null, "1", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"gateway_host": "GatewayService:gateway.local",
			"metric_name": "DASHBOARD_REQUEST_2XX"
		}, {
			"data": [null, "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"gateway_host": "GatewayService:gateway.local",
			"metric_name": "DASHBOARD_REQUEST_3XX"
		}],
		"gateway_metrics": [{
			"gateway_code": "GatewayService",
			"data": [null, "82", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"metric_name": "DASHBOARD_TRAFFIC_READ"
		}, {
			"gateway_code": "GatewayService",
			"data": [null, "405", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"metric_name": "DASHBOARD_TOTAL_REQUEST_TIME"
		}, {
			"gateway_code": "GatewayService",
			"data": [null, "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"metric_name": "DASHBOARD_REQUEST_5XX"
		}, {
			"gateway_code": "GatewayService",
			"data": [null, "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"metric_name": "DASHBOARD_REQUEST_4XX"
		}, {
			"gateway_code": "GatewayService",
			"data": [null, "1", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"metric_name": "DASHBOARD_TOTAL_SUCCESS_REQUEST_COUNT"
		}, {
			"gateway_code": "GatewayService",
			"data": [null, "1", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"metric_name": "DASHBOARD_TOTAL_REQUEST_COUNT"
		}, {
			"gateway_code": "GatewayService",
			"data": [null, "1", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"metric_name": "DASHBOARD_REQUEST_2XX"
		}, {
			"gateway_code": "GatewayService",
			"data": [null, "2947", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"metric_name": "DASHBOARD_TRAFFIC_WRITE"
		}, {
			"gateway_code": "GatewayService",
			"data": [null, "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
			"metric_name": "DASHBOARD_REQUEST_3XX"
		}]
	}
}
```

