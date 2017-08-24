-- set foreign_key_checks = 0;
-- DROP TABLE IF EXISTS erp_inquiry_bilwfw;
-- CREATE TABLE `erp_inquiry_bilwfw` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `billId` bigint(20) DEFAULT NULL COMMENT '单码  erp_inquiry_bil_id',
--   `billStatus` varchar(50) NOT NULL COMMENT '单状态',
--   `prevId` bigint(20) DEFAULT NULL COMMENT '前个步骤',
--   `userId` bigint(20) NOT NULL COMMENT '登录用户编码',
--   `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
--   `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
--   `name` varchar(100) NOT NULL COMMENT '步骤名称',
--   `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
--   `said` varchar(255) DEFAULT NULL COMMENT '步骤附言',
--   `memo` varchar(255) DEFAULT NULL COMMENT '其他关联',
--   PRIMARY KEY (`id`),
--   KEY `erp_inquiry_bilwfw_userId_idx` (`userId`),
--   KEY `erp_inquiry_bilwfw_billStatus_idx` (`billId`,`billStatus`),
--   KEY `erp_inquiry_bilwfw_status_idx` (`billStatus`),
--   KEY `erp_inquiry_bilwfw_opTime_idx` (`opTime`),
--   CONSTRAINT `fk_erp_inquiry_bilwfw_billId` FOREIGN KEY (`billId`) REFERENCES `erp_inquiry_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='报价单流程步骤＃--sn=TB04103&type=mdsFlow&jname=InquiryOfferBillStep&title=报价单状态&finds={"billId":1,"billStatus":1,"userId":1,"opTime":1}'
-- ;

DROP TRIGGER IF EXISTS tr_erpinquiry_bilwfw_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erpinquiry_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_inquiry_bilwfw` FOR EACH ROW BEGIN
	DECLARE aid BIGINT(20);
	declare aName VARCHAR(100);
	DECLARE aNeedTime datetime;
	DECLARE aErc$telgeo_contact_id bigint(20);
	if isnull(new.empId) then
		if exists(select 1 from autopart01_security.sec$user a where a.id = new.userId) THEN
			select a.id, a.name into aid, aName
				from autopart01_crm.`erc$staff` a where a.userId = new.userId;
			set new.empId = aid, new.empName = aName;
		ELSE
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增操作记录，必须指定有效的创建人！';
		end if;
	end if;
	set new.opTime = CURRENT_TIMESTAMP();

	if new.billStatus <> 'justcreated' then
				update erp_inquiry_bil a 
				set a.lastModifiedDate = CURRENT_TIMESTAMP(), a.lastModifiedId = new.userId
				, a.lastModifiedEmpId = new.empId, a.lastModifiedEmpName = new.empName
				where a.id = new.billId;
		END IF;
	
	if new.billStatus = 'submitthatedit' then  -- 提交跟单
		IF EXISTS(SELECT 1 FROM erp_inquiry_bil a WHERE a.isSubmit = 1 AND a.id = new.billId) THEN
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '该单据已提交跟单，请等待跟单操作！';
		END IF;
		update erp_inquiry_bil a set a.isSubmit = 1 where a.id = new.billId;
	elseif new.billStatus = 'thatreplyedit' then  -- 跟单“回复”给客服
		IF EXISTS(SELECT 1 FROM erp_inquiry_bil a WHERE a.isSubmit = 0 AND a.id = new.billId) THEN
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '该单据已回复客服，不能重复回复！';
		END IF;
		update erp_inquiry_bil a set a.isSubmit = 0 where a.id = new.billId;
	elseif new.billStatus = 'submitthatview' then  -- 提交待审
		if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.billId and a.billStatus = 'submitthatview') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已提交，不能重复提交！';
		end if;
	elseif new.billStatus = 'checked' then -- 转销售订单
		if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.billId and a.billStatus = 'checked') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已转销售订单，不能重复操作！';
		end if;
		IF EXISTS(SELECT 1 FROM erp_vendi_detail a WHERE a.erp_inquiry_bil_id = new.billId AND ISNULL(a.goodsId)) THEN 
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '没有指定有效的商品，不能转为销售订单！';
		END IF;
		IF EXISTS(SELECT 1 FROM erp_vendi_detail a WHERE a.erp_inquiry_bil_id = new.billId AND ISNULL(a.ers_packageAttr_id)) THEN
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '没有指定商品包裹单位，不能转为销售订单！';
		END IF;
		IF EXISTS(SELECT 1 FROM erp_vendi_detail a WHERE a.erp_inquiry_bil_id = new.billId AND ISNULL(a.packageQty)) THEN
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '没有指定商品包裹数量，不能转为销售订单！';
		END IF;
		IF EXISTS(SELECT 1 FROM erp_vendi_detail a WHERE a.erp_inquiry_bil_id = new.billId AND ISNULL(a.packagePrice)) THEN
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '请先向跟单询价才能转为销售订单！';
		END IF;
		select a.needTime, a.erc$telgeo_contact_id into aNeedTime, aErc$telgeo_contact_id
		from erp_inquiry_bil a where a.id = new.billId;
		if isnull(aErc$telgeo_contact_id) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '转销售订单，必须指定发货地址！';
		end if;
-- 		select a.userName into aName from autopart01_crm.`erc$staff` a where a.userId = new.userId;
		insert into erp_vendi_bil(erp_inquiry_bil_id, customerId, creatorId, createdDate, needTime, erc$telgeo_contact_id
			, createdBy, lastModifiedId, lastModifiedBy, empId, empName) 
		select new.billId, a.customerId, new.userId, now(), aNeedTime, aErc$telgeo_contact_id
			, aName, new.userId, aName, aId, aName
		from erp_inquiry_bil a WHERE a.id = new.billId
		;
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能生成销售订单主表!';
		ELSE
			set aid = LAST_INSERT_ID();
-- 				-- 登记销售明细对应的销售订单主表
-- 			update erp_vendi_detail a inner join erp_inquiry_bil b on b.id = a.erp_inquiry_bil_id
-- 			set a.erp_vendi_detail_id = aid
-- 			where b.id = new.billId and a.isBuy = 1;
-- 			if ROW_COUNT() = 0 THEN
-- 				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能登记销售明细对应的销售订单主表!';
-- 			end if;
		end if;
		
-- 		IF (SELECT 1 FROM erp_vendi_bilwfw a WHERE a.billId = aid AND a.billStatus = 'justcreated') IS NULL THEN 
-- 			insert into autopart01_erp.erp_vendi_bilwfw (billId, billStatus, userId, name, opTime) 
-- 			values (aid, 'justcreated', new.`userId`, '刚刚创建', CURRENT_TIMESTAMP());
-- 			if ROW_COUNT() = 0 THEN
-- 				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能写入销售订单状态表!';
-- 			end if;
-- 		END IF;
	end if;
end;;
DELIMITER ;
-- DROP TRIGGER IF EXISTS tr_erpinquiry_bilwfw_AFTER_INSERT;
-- DELIMITER ;;
-- CREATE TRIGGER `tr_erpinquiry_bilwfw_AFTER_INSERT` AFTER INSERT ON `erp_inquiry_bilwfw` FOR EACH ROW BEGIN
-- 	if new.billStatus <> 'justcreated' then
-- 			update erp_inquiry_bil a 
-- 			set a.lastModifiedDate = CURRENT_TIMESTAMP(), a.lastModifiedId = new.userId
-- 			, a.lastModifiedEmpId = new.empId, a.lastModifiedEmpName = new.empName
-- 			where a.id = new.billId;
-- 	END IF;
-- end;;
-- DELIMITER ;