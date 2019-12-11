CREATE DATABASE  IF NOT EXISTS `ngr` /*!40100 DEFAULT CHARACTER SET utf8 COLLATE utf8_bin */;
USE `ngr`;

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
 SET NAMES utf8 ;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `c_api_group`
--

DROP TABLE IF EXISTS `c_api_group`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_api_group` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT,
  `group_name` varchar(32) NOT NULL COMMENT '组名称/服务名称',
  `group_context` varchar(250) DEFAULT NULL,
  `upstream_domain_name` varchar(64) DEFAULT NULL COMMENT '后端服务内网域名',
  `upstream_service_id` varchar(64) NOT NULL DEFAULT '0' COMMENT '后端服务（后端服务基于服务发现与注册机制才会用到，网关实现动态负载均衡策略）',
  `enable_balancing` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否启用动态负载均衡（即支持后端服务动态发现，1: 启用，0:禁用）',
  `need_auth` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否需要授权0不需要1需要',
  `lb_algo` tinyint(4) DEFAULT NULL COMMENT '负载均衡算法： 1. 轮训 2.客户端ip_hash',
  `enable` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否启用，用于实现降级，1:启用，0:禁用',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最后更新时间',
  `host_id` int(12) NOT NULL,
  `gen_trace_id` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否生成全局id，1:启用，0:禁用',
  `include_context` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'upstream是否包含context（1：包含，0：不包含）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_host_group_context` (`host_id`,`group_context`)
) ENGINE=InnoDB AUTO_INCREMENT=832 DEFAULT CHARSET=utf8 COMMENT='API组配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_api_group`
--

LOCK TABLES `c_api_group` WRITE;
/*!40000 ALTER TABLE `c_api_group` DISABLE KEYS */;
/*!40000 ALTER TABLE `c_api_group` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_co_parameter`
--

DROP TABLE IF EXISTS `c_co_parameter`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_co_parameter` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `plugin_name` varchar(50) NOT NULL COMMENT '插件名称',
  `biz_id` int(12) unsigned NOT NULL COMMENT '业务ID',
  `property_type` varchar(50) NOT NULL COMMENT '特征类型： URI,IP,Referer,UserAgent,Header,Query_String,PostParam,JsonParam，Host',
  `property_name` varchar(50) NOT NULL COMMENT '特征属性名称，如token，username，若类型是ip，uri, user_agent特征类型也是特征名称',
  `create_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_param_biz_type_name` (`plugin_name`,`biz_id`,`property_type`,`property_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='关联参数信息表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_co_parameter`
--

LOCK TABLES `c_co_parameter` WRITE;
/*!40000 ALTER TABLE `c_co_parameter` DISABLE KEYS */;
/*!40000 ALTER TABLE `c_co_parameter` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_err_resp_template`
--

DROP TABLE IF EXISTS `c_err_resp_template`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_err_resp_template` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `plugin_name` varchar(50) NOT NULL COMMENT '插件名: api_router,group_rate_limit,waf,property_rate_limit',
  `biz_id` int(12) NOT NULL COMMENT '业务id',
  `content_type` varchar(100) NOT NULL COMMENT '内容类型:application/json,application/xml,text/html,text/plain',
  `message` varchar(1500) NOT NULL COMMENT '内容',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `http_status` varchar(4) DEFAULT NULL COMMENT 'http状态码',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_plugin_biz_id` (`plugin_name`,`biz_id`)
) ENGINE=InnoDB AUTO_INCREMENT=127 DEFAULT CHARSET=utf8 COMMENT='自定义响应信息';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_err_resp_template`
--

LOCK TABLES `c_err_resp_template` WRITE;
/*!40000 ALTER TABLE `c_err_resp_template` DISABLE KEYS */;
/*!40000 ALTER TABLE `c_err_resp_template` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_gateway`
--

DROP TABLE IF EXISTS `c_gateway`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_gateway` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `gateway_code` varchar(50) NOT NULL COMMENT '网关code',
  `gateway_desc` varchar(150) NOT NULL COMMENT '网关描述',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `limit_count` int(12) unsigned NOT NULL COMMENT '限速的次数',
  `limit_period` int(10) unsigned NOT NULL DEFAULT '1' COMMENT '限速的周期',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_gateway_code` (`gateway_code`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8 COMMENT='网关信息';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_gateway`
--

LOCK TABLES `c_gateway` WRITE;
/*!40000 ALTER TABLE `c_gateway` DISABLE KEYS */;
INSERT INTO `c_gateway` VALUES (1,'GatewayService','架构基础服务网关','0000-00-00 00:00:00','0000-00-00 00:00:00',100000,1);
/*!40000 ALTER TABLE `c_gateway` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_global_property`
--

DROP TABLE IF EXISTS `c_global_property`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_global_property` (
  `id` int(12) NOT NULL,
  `param_name` varchar(100) NOT NULL COMMENT '配置参数名',
  `param_value` varchar(100) NOT NULL COMMENT '配置参数值',
  `enable` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否启用 1:启用 0：禁用',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最后更新时间',
  PRIMARY KEY (`id`),
  KEY `uk_property_name` (`param_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='全局配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_global_property`
--

LOCK TABLES `c_global_property` WRITE;
/*!40000 ALTER TABLE `c_global_property` DISABLE KEYS */;
INSERT INTO `c_global_property` VALUES (1,'GLOBAL_RATE_LIMIT_COUNT','7000',1,'2018-04-12 11:53:17','2018-08-22 11:12:26'),(2,'GLOBAL_RATE_LIMIT_PERIOD','1',1,'2018-04-12 11:53:47','2018-08-22 11:12:26'),(3,'AUTH_SERVER_DOMAIN_NAME','http://test.com:1188',1,'2018-05-08 10:15:09','2018-06-08 02:27:30'),(4,'AUTH_SERVER_NGR_APP_ID','114',1,'2018-04-12 11:53:47','2019-08-03 04:28:14'),(5,'AUTH_SERVER_NGR_APP_KEY','%$Husersyste_A)SI_gateway_)(IKQAJ%)',1,'2018-04-12 11:53:47','2019-08-03 04:28:14'),(6,'BALANCE_RETRIES_COUNT','6',1,'2018-08-06 18:03:30','2018-08-06 10:03:30'),(7,'BALANCE_CONNECTION_TIMEOUT','600000',1,'2018-08-06 18:03:30','2018-10-09 10:25:28'),(8,'BALANCE_SEND_TIMEOUT','600000',1,'2018-08-06 18:03:31','2018-10-09 10:13:03'),(9,'BALANCE_READ_TIMEOUT','600000',1,'2018-08-06 18:03:31','2018-10-09 10:13:03');
/*!40000 ALTER TABLE `c_global_property` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_gray_divide`
--

DROP TABLE IF EXISTS `c_gray_divide`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_gray_divide` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `gray_divide_name` varchar(100) NOT NULL COMMENT '灰度分流器名称',
  `group_id` int(12) unsigned NOT NULL COMMENT 'c_api_group的主键',
  `gray_domain` varchar(100) NOT NULL DEFAULT '' COMMENT '分流器域名服务',
  `selector_id` int(12) unsigned NOT NULL COMMENT '选择器主键',
  `enable` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否启用，1:启用，0:禁用',
  `create_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `seq_num` int(4) unsigned NOT NULL DEFAULT '0' COMMENT '序号',
  PRIMARY KEY (`id`),
  KEY `c_gray_divide_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='灰度分流器表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_gray_divide`
--

LOCK TABLES `c_gray_divide` WRITE;
/*!40000 ALTER TABLE `c_gray_divide` DISABLE KEYS */;
/*!40000 ALTER TABLE `c_gray_divide` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_group_rate_limit`
--

DROP TABLE IF EXISTS `c_group_rate_limit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_group_rate_limit` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT,
  `group_id` int(12) NOT NULL COMMENT 'API组ID',
  `rate_limit_count` int(12) NOT NULL COMMENT '限流值',
  `rate_limit_period` int(12) NOT NULL COMMENT '限流时间单位: 1s,60s, 3600s, 3600*24s',
  `enable` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否启用1:启用 0.禁用',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `uk_group_id` (`group_id`)
) ENGINE=InnoDB AUTO_INCREMENT=64 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_group_rate_limit`
--

LOCK TABLES `c_group_rate_limit` WRITE;
/*!40000 ALTER TABLE `c_group_rate_limit` DISABLE KEYS */;
/*!40000 ALTER TABLE `c_group_rate_limit` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_group_target`
--

DROP TABLE IF EXISTS `c_group_target`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_group_target` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `group_id` int(12) unsigned NOT NULL COMMENT '组ID',
  `host` varchar(50) NOT NULL COMMENT 'IP地址',
  `port` varchar(10) NOT NULL COMMENT '端口',
  `weight` int(4) DEFAULT NULL COMMENT '权重',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `gray_divide_id` int(12) unsigned NOT NULL DEFAULT '0' COMMENT '灰度分流器主键，默认是0，表示非灰度节点',
  `is_only_ab` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否仅用于AB分流（1：仅用于AB分流）',
  `enable` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否启用，1:启用，0:禁用',
  PRIMARY KEY (`id`,`created_at`),
  UNIQUE KEY `uk_gid_host_port` (`group_id`,`host`,`port`)
) ENGINE=InnoDB AUTO_INCREMENT=980 DEFAULT CHARSET=utf8 COMMENT='API服务组目标节点配置';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_group_target`
--

LOCK TABLES `c_group_target` WRITE;
/*!40000 ALTER TABLE `c_group_target` DISABLE KEYS */;
/*!40000 ALTER TABLE `c_group_target` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_host`
--

DROP TABLE IF EXISTS `c_host`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_host` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `gateway_id` int(12) NOT NULL COMMENT '所属网关id',
  `host` varchar(50) NOT NULL COMMENT '主机（host）',
  `host_desc` varchar(150) NOT NULL COMMENT '主机描述',
  `enable` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否启用，用于实现降级，1:启用，0:禁用',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `limit_count` int(12) unsigned NOT NULL COMMENT '限速的次数',
  `limit_period` int(10) unsigned NOT NULL DEFAULT '1' COMMENT '限速的周期',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_host` (`host`)
) ENGINE=InnoDB AUTO_INCREMENT=156 DEFAULT CHARSET=utf8 COMMENT='主机信息';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_host`
--

LOCK TABLES `c_host` WRITE;
/*!40000 ALTER TABLE `c_host` DISABLE KEYS */;
INSERT INTO `c_host` VALUES (1,1,'gateway.local','gateway.local',1,'2019-07-23 12:17:27','2019-08-03 04:26:50',10000,1),(2,1,'127.0.0.1','127.0.0.1',1,'2019-07-23 15:18:12','2019-08-03 04:26:50',10000,1),(155,1,'localhost','localhost',1,'2019-07-23 15:19:08','2019-07-23 07:19:08',10000,1);
/*!40000 ALTER TABLE `c_host` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_plugin`
--

DROP TABLE IF EXISTS `c_plugin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_plugin` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT,
  `plugin_name` varchar(50) NOT NULL COMMENT '插件名称（英文），唯一',
  `plugin_desc` varchar(100) NOT NULL COMMENT '插件描述',
  `with_selector` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否需要关联选择器使用1:是 0:否',
  `enable` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否启用1:启用 0.禁用',
  `is_built_in` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否内建插件(内建插件不能禁用)1:是 0.否',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `uk_plugin_name` (`plugin_name`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8 COMMENT='网关功能插件配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_plugin`
--

LOCK TABLES `c_plugin` WRITE;
/*!40000 ALTER TABLE `c_plugin` DISABLE KEYS */;
INSERT INTO `c_plugin` VALUES (1,'global_rate_limit','全局限流插件',0,1,1,'2018-05-09 20:51:30','2018-07-07 08:06:35'),(2,'property_rate_limit','根据请求参数特征限流防刷插件',0,1,0,'2018-05-09 20:51:30','2018-08-23 02:37:23'),(3,'waf','防火墙插件',1,1,0,'2018-05-09 20:51:30','2019-07-23 07:36:16'),(4,'group_rate_limit','API组限流控制插件',0,1,1,'2018-05-09 20:51:30','2018-05-30 11:20:59'),(5,'api_router','API路由器插件',0,1,1,'2018-05-09 20:51:30','2018-05-09 12:51:30'),(6,'stat_dashboard','运行概况统计报表',0,1,1,'2018-05-09 20:51:30','2018-05-30 11:20:59'),(7,'statsd_metrics','statsd打点',0,0,0,'2018-05-09 20:51:30','2019-07-23 07:36:46'),(8,'global_access_control','全局控制',0,1,1,'2018-05-16 18:46:04','2018-05-29 07:36:49'),(10,'anti_sql_injection','sql防控器',0,1,0,'2018-10-16 12:47:45','2018-10-16 04:47:45');
/*!40000 ALTER TABLE `c_plugin` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_rel_gray_target`
--

DROP TABLE IF EXISTS `c_rel_gray_target`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_rel_gray_target` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `gray_divide_id` int(12) unsigned NOT NULL COMMENT 'c_gray_divide主键',
  `target_id` int(12) unsigned NOT NULL COMMENT 'c_group_target主键',
  `create_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='AB分流与target关系表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_rel_gray_target`
--

LOCK TABLES `c_rel_gray_target` WRITE;
/*!40000 ALTER TABLE `c_rel_gray_target` DISABLE KEYS */;
/*!40000 ALTER TABLE `c_rel_gray_target` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_selector`
--

DROP TABLE IF EXISTS `c_selector`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_selector` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT,
  `selector_name` varchar(50) NOT NULL COMMENT '选择器名称',
  `selector_type` int(4) NOT NULL COMMENT '选择器类型：1单条件选择器 2多条件取与 3. 多条件取或',
  `enable` tinyint(1) NOT NULL COMMENT '是否启用',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=156 DEFAULT CHARSET=utf8 COMMENT='选择器配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_selector`
--

LOCK TABLES `c_selector` WRITE;
/*!40000 ALTER TABLE `c_selector` DISABLE KEYS */;
/*!40000 ALTER TABLE `c_selector` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `c_selector_condition`
--

DROP TABLE IF EXISTS `c_selector_condition`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `c_selector_condition` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT,
  `selector_id` int(12) NOT NULL COMMENT '选择器ID',
  `param_type` varchar(50) NOT NULL COMMENT '选择条件参数类型：IP，USER_AGENT,QUEYRSTRING, HEADER,REQ_BODY,URL等',
  `condition_opt_type` varchar(50) NOT NULL COMMENT '选择条件匹配类型：equals（相等），not equals(不相等)，match 正则，not math，>,<,>=,<=',
  `param_name` varchar(256) NOT NULL COMMENT '条件参数名称，当param_type为header，queryString，req_body时必须有',
  `param_value` varchar(256) NOT NULL COMMENT '条件参数匹配值',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=184 DEFAULT CHARSET=utf8 COMMENT='选择条件配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `c_selector_condition`
--

LOCK TABLES `c_selector_condition` WRITE;
/*!40000 ALTER TABLE `c_selector_condition` DISABLE KEYS */;
/*!40000 ALTER TABLE `c_selector_condition` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `p_anti_sql_injection`
--

DROP TABLE IF EXISTS `p_anti_sql_injection`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `p_anti_sql_injection` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `group_id` int(12) unsigned NOT NULL COMMENT 'c_api_group的主键',
  `path` varchar(300) NOT NULL COMMENT '服务路径',
  `remark` varchar(300) NOT NULL COMMENT '描述',
  `enable` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否启用，1:启用，0:禁用',
  `create_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `database_type` varchar(30) DEFAULT NULL COMMENT '数据库类型',
  PRIMARY KEY (`id`),
  KEY `index_anti_sql_injection_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='防sql注入表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `p_anti_sql_injection`
--

LOCK TABLES `p_anti_sql_injection` WRITE;
/*!40000 ALTER TABLE `p_anti_sql_injection` DISABLE KEYS */;
/*!40000 ALTER TABLE `p_anti_sql_injection` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `p_prl_property_detial`
--

DROP TABLE IF EXISTS `p_prl_property_detial`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `p_prl_property_detial` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `prl_id` int(12) unsigned NOT NULL COMMENT '特征限速id',
  `property_type` varchar(50) NOT NULL COMMENT '特征类型： URI,IP,Referer,UserAgent,Header,Query_String,PostParam,JsonParam',
  `property_name` varchar(50) NOT NULL COMMENT '特征属性名称，如token，username，若类型是ip，uri, user_agent特征类型也是特别名称',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_prl_name_type` (`prl_id`,`property_type`,`property_name`)
) ENGINE=InnoDB AUTO_INCREMENT=47 DEFAULT CHARSET=utf8 COMMENT='特征信息';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `p_prl_property_detial`
--

LOCK TABLES `p_prl_property_detial` WRITE;
/*!40000 ALTER TABLE `p_prl_property_detial` DISABLE KEYS */;
/*!40000 ALTER TABLE `p_prl_property_detial` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `p_property_rate_limit`
--

DROP TABLE IF EXISTS `p_property_rate_limit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `p_property_rate_limit` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `rate_limit_count` int(12) NOT NULL COMMENT '限流值',
  `rate_limit_period` varchar(50) NOT NULL COMMENT '限流单位: 1s, 60s,3600s,3600*24s',
  `enable` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否启用1:启用 0.禁用',
  `is_blocked` tinyint(1) NOT NULL COMMENT '是否防刷阻止请求1：阻塞，0：非阻塞''',
  `block_time` int(12) DEFAULT NULL COMMENT '防刷阻止请求时间，以分钟为单位，建议最多24小时',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `rate_type` tinyint(1) DEFAULT NULL COMMENT '限流类型：0. 全天，1. 时间段',
  `effect_s_time` varchar(10) DEFAULT NULL COMMENT '影响开始时间(HH:mm:ss)',
  `effect_e_time` varchar(10) DEFAULT NULL COMMENT '影响结束时间(HH:mm:ss)',
  `host_id` int(12) unsigned NOT NULL DEFAULT '0' COMMENT '主机主键',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='特征限流防刷配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `p_property_rate_limit`
--

LOCK TABLES `p_property_rate_limit` WRITE;
/*!40000 ALTER TABLE `p_property_rate_limit` DISABLE KEYS */;
/*!40000 ALTER TABLE `p_property_rate_limit` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `p_waf`
--

DROP TABLE IF EXISTS `p_waf`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `p_waf` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL COMMENT '防火墙名称',
  `is_allowed` tinyint(1) NOT NULL COMMENT '1:allowed 0:deny',
  `enable` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否启用',
  `selector_id` int(12) NOT NULL COMMENT '此防火墙使用的选择器ID',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `host_id` int(12) unsigned NOT NULL DEFAULT '0' COMMENT '主机主键',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=142 DEFAULT CHARSET=utf8 COMMENT='防火墙插件使用配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `p_waf`
--

LOCK TABLES `p_waf` WRITE;
/*!40000 ALTER TABLE `p_waf` DISABLE KEYS */;
/*!40000 ALTER TABLE `p_waf` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `u_admin_user`
--

DROP TABLE IF EXISTS `u_admin_user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `u_admin_user` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(60) NOT NULL DEFAULT '' COMMENT '用户名',
  `password` varchar(200) NOT NULL DEFAULT '' COMMENT '密码',
  `is_admin` tinyint(4) NOT NULL DEFAULT '0' COMMENT '是否是管理员账户：0否，1是',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '创建或者更新时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `mobile` varchar(15) DEFAULT NULL COMMENT '手机',
  `email` varchar(30) DEFAULT NULL COMMENT '邮箱',
  `superior` varchar(30) DEFAULT NULL COMMENT '上级',
  `enable` tinyint(1) DEFAULT '1' COMMENT '启禁用: 1:启用，0:禁用',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8 COMMENT='Backend admin users information';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `u_admin_user`
--

LOCK TABLES `u_admin_user` WRITE;
/*!40000 ALTER TABLE `u_admin_user` DISABLE KEYS */;
INSERT INTO `u_admin_user` VALUES (1,'admin','17837406a010ece7ee83bf1981b6d936a2454526f87d4e0f8036ab28a3648117',1,'2019-07-16 07:41:13','2019-07-15 23:41:13','17811982250','lj4418@126.com','',1),(3,'api_user','66023c3b61ef3c49c96b55370d7ec640eb929d5ef0ada9a552de0e1e28d663e7',1,'2019-07-16 07:41:31','2019-07-15 23:41:31','17811982250','lj4418@126.com','',1);
/*!40000 ALTER TABLE `u_admin_user` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `u_user_log`
--

DROP TABLE IF EXISTS `u_user_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `u_user_log` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `username` varchar(60) CHARACTER SET utf8 NOT NULL COMMENT '操作用户',
  `module` varchar(50) CHARACTER SET utf8 NOT NULL COMMENT '组件:(api_router:路由、property_rate_limit：特征...)',
  `module_desc` varchar(150) CHARACTER SET utf8 NOT NULL COMMENT '组件描述:(api_router:路由、property_rate_limit：特征...)',
  `operation_type` varchar(20) CHARACTER SET utf8 NOT NULL COMMENT '操作类型:(MODIFY:修改、ADD:增加、DELETE:删除)',
  `operation_desc` varchar(20) CHARACTER SET utf8 NOT NULL COMMENT '操作类型描述:(MODIFY:修改、ADD:增加、DELETE:删除)',
  `in_param` text CHARACTER SET utf8 NOT NULL COMMENT '入参',
  `create_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='用户操作记录';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `u_user_log`
--

LOCK TABLES `u_user_log` WRITE;
/*!40000 ALTER TABLE `u_user_log` DISABLE KEYS */;
/*!40000 ALTER TABLE `u_user_log` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
