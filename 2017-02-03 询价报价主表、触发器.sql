CREATE TABLE `erp_inquiry_bil` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `customerId` bigint(20) NOT NULL COMMENT '客户  必填项目',
  `ischeck` tinyint(4) DEFAULT '0' COMMENT '是否提交审核。0：客服可操作（和客户交流更改数据、提交跟单、提交审核）；1：客服不可操作',
  `isSubmit` tinyint(4) DEFAULT '0' COMMENT '单据由客服还是跟单操作。1：跟单 0：客服',
  `creatorId` bigint(20) NOT NULL COMMENT '初建人编码；--@CreatorId 公司的客服 sec$user_id',
  `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID；--@ 公司的客服 erc$staff_id',
  `updaterId` bigint(20) DEFAULT NULL COMMENT '报价人编码；--@UpdaterId  自己的跟单 ',
  `updateEmpId` bigint(20) DEFAULT NULL COMMENT '报价人员工ID；--@UpdaterId  自己的跟单 erc$staff_id',
  `checkUserId` bigint(20) DEFAULT NULL COMMENT '审核用户登录ID',
  `checkEmpId` bigint(20) DEFAULT NULL COMMENT '审核员工ID',
  `priceSumCome` decimal(20,4) DEFAULT NULL COMMENT '进价金额总计',
  `priceSumSell` decimal(20,4) DEFAULT NULL COMMENT '售价金额总计',
  `priceSumShip` decimal(20,4) DEFAULT NULL COMMENT '运费金额总计',
  `zoneNum` varchar(30) DEFAULT NULL COMMENT '客户所在地区的区号 触发器获取',
  `code` varchar(100) DEFAULT NULL COMMENT '询价单号  新增记录时由触发器生成',
  `quoteCode` varchar(100) DEFAULT NULL COMMENT '报价单号  updaterId值由空变非空时由触发器生成，写入后不可变更',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名 客服',
  `updateEmpName` varchar(100) DEFAULT NULL COMMENT '报价人姓名 跟单',
  `checkEmpName` varchar(100) DEFAULT NULL COMMENT '审核员工姓名',
  `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
  `createdBy` varchar(100) DEFAULT NULL COMMENT '登录账户名称  初建人名称；--@CreatedBy',
  `lastModifiedDate` datetime DEFAULT NULL COMMENT '最新修改时间；--@LastModifiedDate',
  `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新修改人编码；每一次变更数据前台必须填写',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID；触发器维护 erc$staff_id',
  `lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新修改员工姓名',
  `lastModifiedBy` varchar(100) DEFAULT NULL COMMENT '最新修改人员；--@LastModifiedBy',
  `needTime` datetime DEFAULT NULL COMMENT '期限时间  客户要求什么时间到货',
  `erc$telgeo_contact_id` bigint(20) DEFAULT NULL COMMENT '公司自提，发货地址和电话_id',
  `takeGeoTel` varchar(1000) DEFAULT NULL COMMENT '发货地址和电话；--这里用文本不用ID，防止本单据流程中地址被修改了',
  `memo` varchar(1000) DEFAULT NULL COMMENT '备注',
  `img` longtext COMMENT '选择图片',
  `jsonimg` longtext,
  `pasteimg` longtext,
  PRIMARY KEY (`id`),
  UNIQUE KEY `erp_inquiry_bil_code_UNIQUE` (`code`),
  KEY `erp_inquiry_bil_customerId_idx` (`customerId`),
  KEY `erp_inquiry_bil_creatorId_idx` (`creatorId`),
  KEY `erp_inquiry_bil_updaterId_idx` (`updaterId`),
  KEY `erp_inquiry_bil_createdDate_idx` (`createdDate`)
) ENGINE=InnoDB AUTO_INCREMENT=330 DEFAULT CHARSET=utf8mb4 COMMENT='询价报价单主表＃--sn=TB04101&type=mdsMaster&jname=InquiryOfferBill&title=询价报价单&finds={"code":1,"createdDate":1,"lastModifiedDate":1}';

CREATE TRIGGER `tr_erp_inquiry_bil_BEFORE_INSERT` BEFORE INSERT ON `erp_inquiry_bil` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName, aUserName varchar(100);
	declare zoneNum VARCHAR(100);
	if isnull(new.zoneNum) then
		set new.zoneNum = (select a.zonenum from autopart01_crm.`erc$customer` a where a.id = new.customerId);
		if isnull(new.zoneNum) then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '指定的客户无效或未指定客户的电话区号！',MYSQL_ERRNO = 1001;
		end if;
	end if;
	-- 最后修改用户变更，获取相关信息
	if isnull(new.lastModifiedId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建询价报价单，必须指定最后修改用户！';
	else
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aId, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	end if;
	
	if new.creatorId > 0 then
		if new.updaterId > 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建询价报价单，不能同时指定客服和跟单！';
		else
			if new.creatorId <> new.lastModifiedId THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建询价报价单，客服和最后修改用户必须是同一人！';
			else
				set new.empId = new.lastModifiedEmpId, new.empName = new.lastModifiedEmpName, new.createdBy = new.lastModifiedBy;
			end if;
		end if;
	else
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建询价报价单，必须指定客服！';
	end if;
	-- 生成发货地址文本
	if new.erc$telgeo_contact_id > 0 and isnull(new.takeGeoTel) then
		set new.takeGeoTel = (select concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
				from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id
		);
	end if;
-- 	if exists(select 1 from autopart01_security.sec$user a where a.id = new.creatorId) THEN
-- 		if new.updaterId > 0 THEN
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能同时指定客服和跟单！';
-- 		end if;
-- 		select a.id, a.name, a.userName into aid, aName, aUserName
-- 		from autopart01_crm.`erc$staff` a where a.userId = new.creatorId;
-- 		set new.empId = aid, new.empName = aName, new.createdBy = aUserName
-- 			, new.lastModifiedId = new.creatorId
-- 			, new.lastModifiedEmpId = aId, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName
-- 		;
-- 	ELSE
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增询价单，必须指定创建人！';
-- 	end if;
	set new.ischeck = 0, new.isSubmit = 0, new.createdDate = now(), new.lastModifiedDate = now();
	-- 生成code 区号+8位日期+4位员工id+4位流水
	set new.code = concat(new.zoneNum, date_format(new.createdDate,'%Y%m%d'), LPAD(new.creatorId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from erp_inquiry_bil a 
				where date(a.createdDate) = date(new.createdDate) and a.creatorId = new.creatorId), 0
			) + 1, 4, 0)
	);
end;

CREATE TRIGGER `tr_erp_inquiry_bil_AFTER_INSERT` AFTER INSERT ON `erp_inquiry_bil` FOR EACH ROW begin
	insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
	select new.id, 'justcreated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '客服刚刚创建';
end;

CREATE TRIGGER `tr_erp_inquiry_bil_BEFORE_UPDATE` BEFORE UPDATE ON `erp_inquiry_bil` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName, aUserName varchar(100);
	
	if old.checkUserId > 0 and new.checkUserId > 0 THEN
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '该单据已转为销售订单，不能修改！';
	end if;
	-- 最后修改用户变更，获取相关信息
	if new.lastModifiedId <> old.lastModifiedId then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aId, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	end if;

	-- 获取跟单用户信息
	if isnull(old.updaterId) THEN
		if new.updaterId > 0 THEN
			set new.updateEmpId = new.lastModifiedEmpId, new.updateEmpName = new.lastModifiedEmpName;
			-- 生成quoteCode 区号+8位日期+4位员工id+4位流水
			set new.quoteCode = concat(new.zoneNum, date_format(new.createdDate,'%Y%m%d'), LPAD(new.updaterId,4,0)
				, LPAD(
					ifnull((select max(right(a.quoteCode, 4)) from erp_inquiry_bil a 
						where date(a.createdDate) = date(new.createdDate) and a.updaterId = new.updaterId), 0
					) + 1, 4, 0)
			);
		end if;
	ELSE
		if old.updaterId <> new.updaterId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '已指定跟单，不能变更！';
		end if;
	end if;

	if isnull(old.checkUserId) and new.checkUserId > 0 THEN -- 审核通过转销售单
		if new.ischeck <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单尚未提交审核，不能转销售单！';
		elseif new.checkUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '审核人和最新修改用户应该是同一人！';
		elseif isnull(new.erc$telgeo_contact_id) or isnull(new.takeGeoTel)  THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '转销售订单，必须指定发货地址！';
		end if;
		-- 获取用户相关信息
		set new.checkEmpId = new.lastModifiedEmpId, new.checkEmpName = new.lastModifiedEmpName;
		-- 流程状态在 AFTER INSERT触发器写入
-- 	elseif old.ischeck = 0 and new.ischeck = 1 THEN -- 提交审核
-- 		if isnull(new.updaterId) THEN
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单尚未报价，不能提交审核时！';
-- 		elseif new.customerId <> old.customerId THEN
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单提交审核时不能变更客户！';
-- 		elseif new.lastModifiedId <> new.creatorId THEN
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单只能由客户提交审核！';
-- 		end if;
-- 
-- 		insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
-- 		select new.id, 'submitthatview', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
-- 			, new.lastModifiedBy, '提交审核';
-- 
-- 	elseif old.ischeck = 1 and new.ischeck = 0 THEN -- 审核不通过
-- 		if new.lastModifiedId in (new.creatorId, new.updaterId) THEN
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单不能由客服或跟单审核回退！';
-- 		elseif new.customerId <> old.customerId THEN
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单审核回退时不能变更客户！';
-- 		end if;
-- 
-- 		insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
-- 		select new.id, 'submitBack', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
-- 			, new.lastModifiedBy, '审核回退';

	elseif old.isSubmit = 0 and new.isSubmit = 1 THEN -- 提交跟单
		if new.lastModifiedId <> new.creatorId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单只能由客户提交跟单！';
		end if;
		insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
		select new.id, 'submitthatedit', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, '提交跟单';

	elseif old.isSubmit = 1 and new.isSubmit = 0 THEN -- 跟单“回复”给客服
		if isnull(new.updaterId) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单未指定跟单，不能回复客服！';
		elseif new.lastModifiedId <> new.updaterId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单只能由跟单回复客服！';
		end if;
		insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
		select new.id, 'thatreplyedit', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, '回复客服';
	else
		if new.customerId <> old.customerId then
			set new.zoneNum = (select a.zonenum from autopart01_crm.`erc$customer` a where a.id = new.customerId);
			if isnull(new.zoneNum) then
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未指定客户的电话区号！',MYSQL_ERRNO = 1001;
			else
				-- 生成code 区号+8位日期+4位员工id+4位流水
				set new.code = concat(new.zoneNum, date_format(new.createdDate,'%Y%m%d'), LPAD(new.creatorId,4,0)
					, LPAD(
						ifnull((select max(right(a.code, 4)) from erp_inquiry_bil a 
							where date(a.createdDate) = date(new.createdDate) and a.creatorId = new.creatorId), 0
						) + 1, 4, 0)
				);
			end if;
		END IF;
		-- 生成发货地址
		if new.erc$telgeo_contact_id > 0 and isnull(new.takeGeoTel) 
				and (isnull(old.erc$telgeo_contact_id) or new.erc$telgeo_contact_id <> old.erc$telgeo_contact_id) then
			set new.takeGeoTel = (select concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
							from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id
			);
		end if;
		-- 记录操作记录
		if old.isSubmit = new.isSubmit then
			insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
			SELECT new.id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
				, new.lastModifiedBy, concat(if(new.isSubmit = 0, '客服', '跟单'), '自行修改主表');
		ELSE
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单主表流程错误！';
		end if;
	end if;
	
	set new.lastModifiedDate = CURRENT_TIMESTAMP();	
end;

CREATE TRIGGER `tr_erp_inquiry_bil_AFTER_UPDATE` AFTER UPDATE ON `erp_inquiry_bil` FOR EACH ROW begin
	
	if isnull(old.checkUserId) and new.checkUserId > 0 THEN -- 审核通过转销售单
		call p_inquiry_Sales(new.id);  -- 转销售单
		-- 插入流程状态
		insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
		select new.id, 'checked', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, '审核通过转销售单';
	end if;
end;

CREATE TRIGGER `tr_erp_inquiry_bil_BEFORE_DELETE` BEFORE DELETE ON `erp_inquiry_bil` FOR EACH ROW begin
	if old.checkUserId > 0 THEN -- 审核通过转销售单
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单转销售单，不能删除！';
	elseif old.ischeck = 1 THEN -- 提交审核
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单已提交审核，不能删除！';
	elseif old.isSubmit = 1 THEN -- 提交跟单
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '询价单已提交跟单，不能删除！';
	end if;
	delete a from erp_vendi_detail a where a.erp_inquiry_bil_id = old.id;
end;