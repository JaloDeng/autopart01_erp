-- *********************************************************************************************************************
-- 调用采购进仓存储，增加事务
-- *********************************************************************************************************************
DROP PROCEDURE IF EXISTS `p_call_purchDetail_snCode_shelfattr`;
DELIMITER ;;
CREATE PROCEDURE `p_call_purchDetail_snCode_shelfattr` (
	aids VARCHAR(65535) CHARSET latin1 -- 货物二维码ID erp_purchDetail_snCode.id(集合，用xml格式) 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, shelfattrId bigint(20) -- 货架ID ers_packageAttr_id
	, qty INT(11) -- 入仓商品个数
)
BEGIN
	DECLARE i INT DEFAULT 1;
	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;
	
	START TRANSACTION;

	WHILE i < qty+1 DO
		CALL p_purchDetail_snCode_shelfattr(ExtractValue(aids, '//a[$i]'), uId, shelfattrId);
		SET i = i+1;
	END WHILE;

	COMMIT;  

END;;
DELIMITER ;


-- *********************************************************************************************************************
-- 调用销售出仓存储，增加事务
-- *********************************************************************************************************************
DROP PROCEDURE IF EXISTS `p_call_vendi_snCode_shelfattr`;
DELIMITER ;;
CREATE PROCEDURE `p_call_vendi_snCode_shelfattr` (
	aids VARCHAR(65535) CHARSET latin1 -- 货物二维码ID erp_purchDetail_snCode.id(集合，用xml格式) 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, vdid bigint(20)		-- 销售订单明细表ID erp_sales_detail.id
	, qty INT(11) -- 出仓商品个数
)
BEGIN
	DECLARE i INT DEFAULT 1;
	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;
	
	START TRANSACTION;

	WHILE i < qty+1 DO
		CALL p_vendi_snCode_shelfattr(ExtractValue(aids, '//a[$i]'), vdid, uId);
		SET i = i+1;
	END WHILE;

	COMMIT;  

END;;
DELIMITER ;

-- CREATE DEFINER=`root`@`%` PROCEDURE `p_vendi_snCode_shelfattr`( 
-- 	aid bigint(20) -- 货物二维码ID erp_purchDetail_snCode.id 
-- 	, vdid bigint(20)		-- 销售订单明细表ID erp_sales_detail.id
-- 	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
-- )
-- BEGIN
-- 	declare eid bigint(20);
-- 	DECLARE eName, eUserName varchar(100);
-- 	DECLARE msg, aSort VARCHAR(1000);
-- -- 	declare pid bigint(20);		-- 采购订单主表ID erp_purch_bil.id
-- -- 	declare pdid bigint(20);		-- 采购订单明细表ID erp_purch_detail.id
-- 	declare vid bigint(20);		-- 销售订单主表ID erp_vendi_bil.id
-- 	DECLARE aErp_vendi_bil_goutqty_id, aRoomId, aGoodsId, aErs_packageattr_id, vdErs_packageattr_id, aShelfId bigint(20); 
-- 	DECLARE aCrm_suppliers_id bigint(20); 
-- 	DECLARE aQty, aDegree, vdDegree, vdPackageQty, vdQty, haveOutQty int;
-- 	DECLARE vdPrice dec(20,4);
-- 	DECLARE aState TINYINT; -- 二维码进仓/出仓标志
-- 
-- 
-- 	-- 获取用户相关信息
-- 	call p_get_userInfo(uId, eid, eName, eUserName);
-- 
-- 
-- 	-- 获取二维码的相关信息
-- 	select a.goodsId, a.ers_packageattr_id, a.qty, a.ers_shelfattr_id, s.roomId
-- 		, a.degree, a.state, a.supplierId, a.sSort 
-- 	into aGoodsId, aErs_packageattr_id, aQty, aShelfId, aRoomId
-- 		, aDegree, aState, aCrm_suppliers_id, aSort
-- 	from erp_purchDetail_snCode a INNER JOIN ers_shelfattr s on s.id = a.ers_shelfattr_id
-- 	where a.id = aid;
-- 
-- 	if isnull(aErs_packageattr_id) then
-- 		set msg = concat('指定的配件二维码（编号：', aid,'）不存在，不能完成出仓！');
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 	elseif aState <> 1 THEN
-- 		set msg = concat('指定的配件（编号：', aGoodsId,'）二维码（编号：', aid,'）尚未进仓或已经出仓，不能完成出仓！');
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 	elseif isnull(aRoomId) THEN
-- 		set msg = concat('登记的二维码的仓位（编号：', aShelfId,'）不存在，不能完成进仓！');
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 	end if;
-- 
-- 	-- 获取销售明细相关信息
-- 	select v.id, vd.ers_packageAttr_id, vd.packageQty, vd.salesPackagePrice, vd.qty, p.degree
-- 	into vid, vdErs_packageAttr_id, vdPackageQty, vdPrice, vdQty, vdDegree
-- 	from erp_vendi_bil v INNER JOIN erp_sales_detail vd on v.id = vd.erp_vendi_bil_id
-- 		INNER JOIN ers_packageattr p on p.id = vd.ers_packageAttr_id
-- 	where vd.id = vdid and vd.goodsId = aGoodsId;
-- 	if isnull(vid) THEN
-- 		set msg = concat('指定的销售单明细（编号：', vdid,'）不存在或者配件与指定的二维码（编号：'
-- 			, aid,'）对应的配件（编号：', aGoodsId,'）不匹配，不能完成出仓！');
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 	elseif aDegree > vdDegree THEN
-- 		set msg = concat('指定的销售单明细（编号：', vdid,'）配件包装级别（', vdDegree, '）低于指定的二维码（编号：'
-- 			, aid,'）配件包装级别（', aDegree,'），不能完成出仓！');
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 	end if;
-- 	if exists(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
-- 		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.state = -1
-- 			and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该配件包装存在已经出仓的记录，不能进行整体出仓';
-- 	end if;
-- 	-- 判断该销售明细已经出仓的单品数量 + 指定二维码的单品数量 是否超出 该销售明细实际需要出仓的单品数量
-- 	set haveOutQty = uf_erp_sales_detail_haveOutQty(vdid, aGoodsId);
-- 	if vdQty = haveOutQty THEN
-- 		set msg = concat('指定的销售单明细（编号：', vdid,'）配件（编号：', aGoodsId,'）销售单品数量（', vdQty,'）已经全部出仓！');
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 	elseif aQty + haveOutQty > vdQty THEN
-- 		set msg = concat('指定的销售单明细（编号：', vdid,'）配件（编号：', aGoodsId,'）销售单品数量（', vdQty,'）小于指定的二维码（编号：'
-- 			, aid,'）配件包装单品数量（', aQty,'）与已经出仓的单品数量（', haveOutQty,'）之和，不能完成出仓！');
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 	end if;
-- 	-- 判断二维码的包装在ers_shelfbook表中是否存在，不存在要进行拆包操作
-- 	if not exists(select 1 from ers_shelfbook a 
-- 			where a.ers_packageattr_id = aErs_packageattr_id and a.ers_shelfattr_id = aShelfId
-- -- 				and a.qty > 0
-- 		) THEN
-- 
-- 		call p_snCode_unpack(aid);
-- -- 		-- 获取要修改数量的仓位账簿IDers_shelfbook.id（bid） 、 
-- -- 		-- 要拆包的二维码ID erp_purchDetail_snCode.id（sid）
-- -- -- 		select  a.id, b.id into  bid, sid from ers_shelfbook a INNER JOIN (
-- -- -- 			select DISTINCT a.id, a.ers_packageattr_id, a.ers_shelfattr_id
-- -- -- 			from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_purchDetail_snCode c
-- -- -- 			where a.id = b.parentId 
-- -- -- 			and c.id = 100 and b.nLevel <= c.nLevel
-- -- -- 			and locate(a.sSort, c.sSort) > 0 and locate(b.sSort, c.sSort) = 0
-- -- -- 		) b on b.ers_packageattr_id = a.ers_packageattr_id and b.ers_shelfattr_id = a.ers_shelfattr_id
-- -- -- 		where a.qty > 0
-- -- -- 		;
-- -- 		-- 修改仓位账簿的数量
-- -- 		UPDATE ers_shelfbook a INNER JOIN (
-- -- 			select DISTINCT a.id, a.ers_packageattr_id, a.ers_shelfattr_id, a.qty
-- -- 			from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_purchDetail_snCode c
-- -- 			where a.id = b.parentId 
-- -- 			and c.id = 100 and b.nLevel <= c.nLevel
-- -- 			and locate(a.sSort, c.sSort) > 0 and locate(b.sSort, c.sSort) = 0
-- -- 		) b on b.ers_packageattr_id = a.ers_packageattr_id and b.ers_shelfattr_id = a.ers_shelfattr_id
-- -- 			set a.packageQty = a.packageQty - 1, a.qty = a.qty - b.qty	
-- -- 		where a.qty > 0;
-- -- 		if ROW_COUNT() = 0 THEN
-- -- 			set msg = concat(msg, '未能同步修改需要拆包的仓位账簿！') ;
-- -- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- -- 		end if;
-- -- 		
-- -- 		-- 插入sid拆包后的分包装到二维码拆包记录表
-- -- 		insert into erp_snCode_unpack( ers_packageattr_id, goodsId, roomId, ers_shelfattr_id
-- -- 			, packageQty, qty)
-- -- 		select a.ers_packageattr_id, a.goodsId, a.roomId, a.ers_shelfattr_id
-- -- 			, sum(a.packageQty) as packageQty, sum(a.qty) as qty
-- -- 		from (
-- -- 			select b.id, b.goodsId, b.ers_packageattr_id, b.roomId, b.ers_shelfattr_id, 1 as packageQty, b.qty
-- -- 			from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_purchDetail_snCode c
-- -- 			where a.id = b.parentId and c.id = aid and b.nLevel <= c.nLevel
-- -- 				and locate(a.sSort, c.sSort) > 0 and locate(b.sSort, c.sSort) = 0
-- -- 			union all
-- -- 			select a.id, a.goodsId, a.ers_packageattr_id, a.roomId, a.ers_shelfattr_id, 1 as packageQty, a.qty
-- -- 			from erp_purchDetail_snCode a, erp_purchDetail_snCode b
-- -- 			where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId 
-- -- 				and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort
-- -- 			) a GROUP BY a.ers_packageattr_id, a.ers_shelfattr_id;
-- -- 		if ROW_COUNT() <> 1 THEN
-- -- 			set msg = concat(msg, '未能同步新增二维码拆包记录！') ;
-- -- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- -- 		end if;
-- 	end if;
-- 	-- 写入出仓单
-- 	set msg = concat('配件（编号：', aGoodsId,'）二维码（编号', aid,'）库房（编号', aRoomId
-- 		,'）仓位（编号：', aShelfId,'）出仓时，');
-- 	insert into erp_vendi_bil_goutqty(erp_purchdetail_sncode_id, erp_vendi_bil_id, 
-- 			erp_sales_detail_id, goodsId, ers_packageattr_id, degree, roomId, ers_shelfattr_id, packageQty, qty
-- 			, outTime, outUserId, outEmpId, outEmpName)
-- 		select aid, vid, vdid, aGoodsId, aErs_packageattr_id, aDegree, aRoomId, aShelfId, 1, aQty
-- 			, now(), uId, eid, eName
-- 		;
-- 		if ROW_COUNT() <> 1 then
-- 			set msg = concat(msg, '未能同步新增出仓单明细！');
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- -- 		ELSE
-- -- 			set aErp_vendi_bil_goutqty_id = LAST_INSERT_ID();
-- -- -- SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = aErp_vendi_bil_goutqty_id;
-- 		end if;
-- -- 	-- 获取出仓单编号
-- -- 	select a.id into aErp_vendi_bil_goutqty_id 
-- -- 	from erp_vendi_bil_goutqty a 
-- -- 	where a.erp_sales_detail_id = vdid and a.goodsId = aGoodsId 
-- -- 		and a.ers_packageattr_id = aErs_packageattr_id and a.ers_shelfattr_id = aShelfId;
-- -- 	if aErp_vendi_bil_goutqty_id > 0 THEN
-- -- 		update erp_vendi_bil_goutqty a
-- -- 		set a.packageQty = a.packageQty + 1, a.qty = a.qty + aQty
-- -- 		where a.id = aErp_vendi_bil_goutqty_id;
-- -- 		if ROW_COUNT() <> 1 then
-- -- 			set msg = concat(msg, '未能同步修改出仓单明细');
-- -- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- -- 		end if;
-- -- 	else
-- -- 		insert into erp_vendi_bil_goutqty(
-- -- 			erp_sales_detail_id, goodsId, ers_packageattr_id, roomId, ers_shelfattr_id, packageQty, qty
-- -- 			, outTime, outUserId, outEmpId, outEmpName)
-- -- 		select vdid, aGoodsId, aErs_packageattr_id, aRoomId, aShelfId, 1, aQty
-- -- 			, now(), uId, eid, eName
-- -- 		;
-- -- 		if ROW_COUNT() <> 1 then
-- -- 			set msg = concat(msg, '未能同步新增出仓单明细！');
-- -- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- -- 		ELSE
-- -- 			set aErp_vendi_bil_goutqty_id = LAST_INSERT_ID();
-- -- -- SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = aErp_vendi_bil_goutqty_id;
-- -- 		end if;
-- -- 	end if;
-- 	-- 修改二维码的标志为-1（出仓）
-- 	update erp_purchDetail_snCode a , erp_purchDetail_snCode b set a.state = -1
-- -- 			set a.erp_vendi_bil_goutqty_id = aErp_vendi_bil_goutqty_id
-- -- 				, a.outUserId = uId, a.outEmpId = eId, a.outEmpName = eName
-- -- 				, a.outTime = CURRENT_TIMESTAMP()
-- 	where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId 
-- 			and b.id = aid and b.sSort = left(a.sSort, CHAR_LENGTH(b.sSort))
-- 	;
-- 	if ROW_COUNT() = 0 THEN
-- 		set msg = concat(msg, '未能成功写入二维码出仓标志！');
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 	end if;
-- 
-- -- select pd.id, pd.goodsId, pd.qty
-- -- from erp_purch_bil p INNER JOIN erp_purch_detail pd on p.id = pd.erp_purch_bil_id
-- -- INNER JOIN (
-- -- select  a.goodsId, sum(a.qty)
-- -- from erp_purch_bil_intoqty a
-- -- where a.erp_purch_detail_id = 20
-- -- GROUP BY a.goodsId
-- -- ) a on pd.id = a.erp_purch_detail_id and pd.goodsId = a.goodsId
-- -- where pd.id = 20
-- 	
-- -- 	if not exists(	-- 该二维码对应的采购订单明细是否全部进仓完毕， 完毕登记最新供应商及最新进货价格
-- -- 			select 1 from erp_sales_detail pd INNER JOIN erp_purchDetail_snCode a on pd.id = a.erp_sales_detail_id
-- -- 			where pd.id = pdid and a.degree = 1 and isnull(a.ers_shelfattr_id) limit 1 
-- -- 		) then
-- 
-- 	-- 该二维码对应的采购订单明细是否全部进仓完毕， 完毕登记最新供应商及最新进货价格
-- 	if vdQty = uf_erp_sales_detail_haveOutQty(vdid, aGoodsId) THEN -- 
-- 		-- 登记最新供应商及最新进货价格
-- 		call p_suppliersGoods_setSalesPrice(
-- 				pdErs_packageattr_id		-- 包裹ID
-- 				, aDegree					-- 包裹层级
-- 				, aGoodsId					-- 商品ID
-- 				, aCrm_suppliers_id		-- 供应商ID
-- 				, pdPrice					-- 进货价
-- 		);
-- 		if not exists(select 1 from erp_sales_detail a left JOIN (
-- 					select a.erp_sales_detail_id, sum(a.qty) as sQty from erp_vendi_bil_goutqty a 
-- 								where a.erp_sales_detail_id = vdid -- and a.goodsId = aGoodsId
-- 					GROUP BY a.erp_sales_detail_id
-- 				) b on a.id = b.erp_sales_detail_id and a.erp_sales_detail_id = vdid and a.qty > ifnull(b.sQty, 0) limit 1
-- 			) then
-- 			-- 修改销售订单主表的出仓人等信息
-- 			update erp_vendi_bil a set a.outTime = CURRENT_TIMESTAMP(), a.outUserId = uId, a.outEmpId = eId, a.outEmpName = eName
-- 				, a.lastModifiedId = uId, a.lastModifiedEmpId = eid, a.lastModifiedEmpName = eName, a.lastModifiedBy = aUserName
-- 			where a.id = vid;
-- 			if ROW_COUNT() <> 1 THEN
-- 					set msg = concat(msg, '出仓完毕，未能成功修改出仓时间、出仓人！');
-- 					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 			end if;
-- 		end if;
-- 	end if;
-- end