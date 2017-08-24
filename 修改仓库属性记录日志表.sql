SET FOREIGN_KEY_CHECKS =0;

DROP TABLE IF EXISTS `ers_operation_step`;
CREATE TABLE `ers_operation_step` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `userId` bigint(20) NOT NULL COMMENT '员工编码',
  `empName` bigint(20) NOT NULL COMMENT '员工名称',
	`itemId` bigint(20) NOT NULL COMMENT '对象编码',
  `itemType` varchar(255) NOT NULL COMMENT '对象类型',
  `type` varchar(255) NOT NULL COMMENT '操作类型',
  `opTime` datetime DEFAULT NULL COMMENT '日期时间',
  `memo` varchar(255) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `userId_idx` (`userId`),
  KEY `itemId_idx` (`itemId`),
  KEY `itemType_idx` (`itemType`),
  KEY `opTime_idx` (`opTime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='员工操作资料日志'
;

-- 	********************************************************************************************************************
-- 	修改仓库相关属性记录日志
-- 	********************************************************************************************************************
DROP PROCEDURE IF EXISTS `p_ers_operation_step_log`;
DELIMITER ;;
CREATE PROCEDURE `p_ers_operation_step_log`(
	uid BIGINT(20)	-- autopart01_security.sec$user.id userId
	,itemId BIGINT(20) -- 修改的数据的id
	,itemType VARCHAR(191) -- 代码层entity名
	,type VARCHAR(191) -- c、r、u、d
)
BEGIN
			DECLARE eName VARCHAR(100);
			SET eName = (SELECT a.name FROM autopart01_crm.erc$staff a WHERE a.userId = uid);
			INSERT INTO ers_operation_step(userId, empName, itemId, itemType, type, opTime)
			SELECT uid, eName, itemId, itemType, type, NOW();
END;;
DELIMITER ;

