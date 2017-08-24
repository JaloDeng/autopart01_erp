DROP TRIGGER IF EXISTS tr_erpinquiry_bilwfw_BEFORE_INSERT;

DELIMITER ;;
CREATE TRIGGER `tr_erpinquiry_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_inquiry_bilwfw` FOR EACH ROW BEGIN
	DECLARE aid BIGINT(20);
	declare aName VARCHAR(100);
	DECLARE aNeedTime datetime;
	DECLARE aErc$telgeo_contact_id bigint(20);
	if exists(select 1 from autopart01_security.sec$user a where a.id = new.userId) THEN
		if new.billStatus <> 'justcreated' and new.billStatus <> 'append' and new.billStatus <> 'selfupdated' then
			select a.id, a.name into aid, aName
			from autopart01_crm.`erc$staff` a where a.userId = new.userId;
			set new.empId = aid, new.empName = aName;
			update erp_inquiry_bil a 
			set a.lastModifiedDate = CURRENT_TIMESTAMP(), a.lastModifiedId = new.userId, a.lastModifiedEmpId = aid, a.lastModifiedEmpName = aName
			where a.id = new.billId;
		end if;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增操作记录，必须指定有效的创建人！';
	end if;
	if new.billStatus = 'submitthatedit' then  -- 提交跟单
		update erp_inquiry_bil a set a.isSubmit = 1 where a.id = new.billId;
	elseif new.billStatus = 'thatreplyedit' then  -- 跟单“回复”给客服
		update erp_inquiry_bil a set a.isSubmit = 0 where a.id = new.billId;
	elseif new.billStatus = 'submitthatview' then  -- 提交待审
		if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.billId and a.billStatus = 'submitthatview') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已提交，不能重复提交！';
		end if;
	elseif new.billStatus = 'checked' then -- 转销售订单
		if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.billId and a.billStatus = 'checked') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已转销售订单，不能重复操作！';
		end if;
		select a.needTime, a.erc$telgeo_contact_id into aNeedTime, aErc$telgeo_contact_id
		from erp_inquiry_bil a where a.id = new.billId;
		if isnull(aErc$telgeo_contact_id) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '转销售订单，必须指定发货地址！';
		end if;
		insert into erp_vendi_bil(erp_inquiry_bil_id, customerId, creatorId, createdDate, needTime, erc$telgeo_contact_id
			, createdBy) 
		select new.billId, a.customerId, new.userId, now(), aNeedTime, aErc$telgeo_contact_id
			, (select a.userName from autopart01_crm.`erc$staff` a where a.userId = new.userId)
		from erp_inquiry_bil a
		;
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能生成销售订单主表!';
		ELSE
			set aid = LAST_INSERT_ID();
		end if;
		IF EXISTS(SELECT 1 FROM erp_vendi_bilwfw a WHERE a.billId = aid AND a.billStatus = 'justcreated') THEN 
			insert into autopart01_erp.erp_vendi_bilwfw (billId, billStatus, userId, name, opTime) 
			values (aid, 'justcreated', new.`userId`, '刚刚创建', CURRENT_TIMESTAMP());
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能写入销售订单状态表!';
			end if;
		END IF;
	end if;
end;;
DELIMITER ;