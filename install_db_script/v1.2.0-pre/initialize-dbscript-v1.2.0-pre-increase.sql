--
-- Table structure for table `c_gateway_instance`
--

DROP TABLE IF EXISTS `c_gateway_instance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
SET character_set_client = utf8mb4 ;
CREATE TABLE `c_gateway_instance` (
                                      `id` bigint(20) NOT NULL AUTO_INCREMENT,
                                      `gateway_id` bigint(20) NOT NULL COMMENT '所属网关ID',
                                      `address` varchar(100) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL COMMENT '网关地址',
                                      `register_time` datetime DEFAULT NULL COMMENT '注册时间',
                                      `renew_time` datetime DEFAULT NULL COMMENT '续约时间',
                                      `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
                                      `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                      PRIMARY KEY (`id`),
                                      UNIQUE KEY `address_UNIQUE` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='网关实例表';
/*!40101 SET character_set_client = @saved_cs_client */;