DROP PROCEDURE IF EXISTS `p_purchDetail_snCode_shelfattrTest`;
DELIMITER ;;
CREATE PROCEDURE `p_purchDetail_snCode_shelfattrTest`( 
	aid bigint(20) -- 货物二维码ID erp_purchDetail_snCode.id 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, shelfattrId bigint(20) -- 货架ID ers_packageAttr_id
)
BEGIN
	declare eid bigint(20);
	DECLARE eName, eUserName varchar(100);
	DECLARE msg VARCHAR(1000);
	declare pid bigint(20);		-- 采购订单主表ID erp_purch_bil.id
	declare pdid bigint(20);		-- 采购订单明细表ID erp_purch_detail.id
	DECLARE aErp_purch_bil_intoqty_id, aRoomId, aGoodsId, aErs_packageattr_id, pdErs_packageattr_id, aCrm_suppliers_id bigint(20); 
	DECLARE aQty, aDegree, pdDegree int;
	DECLARE pdPrice dec(20,4);	
	DECLARE aState TINYINT; -- 二维码进仓/出仓标志

	-- 获取用户相关信息
	call p_get_userInfo(uId, eid, eName, eUserName);

	-- 获取仓位的信息
	select a.roomId into aRoomId from ers_shelfattr a where a.id = shelfattrId;
	if isnull(aRoomId) THEN
		set msg = concat('指定的仓位（编号：', shelfattrId,'）不存在，不能完成进仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 获取二维码所在的采购明细信息
	select p.id, pd.id, a.goodsId, a.ers_packageattr_id, a.qty
		, p.supplierId, pd.ers_packageAttr_id, pd.packagePrice, a.degree
	into pid, pdid, aGoodsId, aErs_packageattr_id, aQty
		, aCrm_suppliers_id, pdErs_packageattr_id, pdPrice, aDegree
	from erp_purch_bil p INNER JOIN erp_purch_detail pd on p.id = pd.erp_purch_bil_id
-- 			INNER JOIN ers_packageattr k on k.id = pd.ers_packageAttr_id
		INNER JOIN erp_purchDetail_snCode a on a.erp_purch_detail_id = pd.id
	where a.id = aid;

	if isnull(pdid) then
		set msg = concat('指定的配件二维码（编号：', aid,'）不存在，不能完成进仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
-- 	select b.id, sum(b.qty) from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_purchDetail_snCode c
-- where a.id = b.parentId 
-- and c.id = 178 and b.nLevel <= c.nLevel
-- and locate(a.sSort, c.sSort) > 0 and locate(b.sSort, c.sSort) = 0
-- ;
-- select a.sSort, b.* from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_purchDetail_snCode c
-- where a.id = b.parentId 
-- and c.id = 178 and b.nLevel <= c.nLevel
-- and locate(a.sSort, c.sSort) > 0 and locate(b.sSort, c.sSort) = 0
-- ;
-- select a.id, a.nLevel, a.parentId, a.sSort, b.id, b.nLevel, b.parentId, b.sSort
-- from erp_purchDetail_snCode a, erp_purchDetail_snCode b
-- where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId 
-- 	and b.id = 1 and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort
-- ;

-- -- 	-- 获得所有的子节点, 存入表id_temp
-- -- 	call p_createTree('erp_purchDetail_snCode', aid);
-- 		
-- -- 	select * from id_temp;
-- -- 	SELECT concat(SPACE(B.nLevel*2),'+--',A.id) FROM erp_purchDetail_snCode A, id_temp B WHERE A.ID=B.ID ORDER BY B.sSort;
-- 	if exists(select 1 from erp_purchDetail_snCode a INNER JOIN id_temp b on a.id = b.id and a.ers_shelfattr_id > 0 limit 1) THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该配件包装存在已经进仓的记录，不能进行整体进仓';
-- 	end if;

	-- 判断二维码是否可以进仓/整体进仓
	if exists(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.state = 1
			and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
		if aDegree > 1 then
			set msg = concat('指定的配件二维码（编号：', aid,'）存在已经进仓的低级包装的记录，不能进行整体进仓！');
		else
			set msg = concat('指定的配件二维码（编号：', aid,'）已经进仓，不能再次进仓！');
		end if;
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	
	set msg = concat('配件（编号：', aGoodsId,'）二维码（编号', aid,'）库房（编号', aRoomId
		,'）仓位（编号：）', shelfattrId,'进仓时，');
	-- 包装数量变化写入采购进仓单
	insert into erp_purch_bil_intoqty(erp_purchDetail_snCode_id, erp_purch_bil_id, erp_purch_detail_id, goodsId, ers_packageattr_id
			, roomId, ers_shelfattr_id, packageQty, qty
			, inTime, inUserId, inEmpId, inEmpName)
		select aid, pid, pdid, aGoodsId, aErs_packageattr_id
			, aRoomId, shelfattrId, 1, aQty
			, now(), uId, eid, eName
		;
		if ROW_COUNT() <> 1 then
			set msg = concat(msg, '未能同步新增进仓单明细！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 		ELSE
-- 			set aErp_purch_bil_intoqty_id = LAST_INSERT_ID();
-- -- SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = aErp_purch_bil_intoqty_id;
		end if;
-- 	-- 获取进仓单编号
-- 	select a.id into aErp_purch_bil_intoqty_id from erp_purch_bil_intoqty a 
-- 	where a.erp_purch_detail_id = pdid and a.ers_packageattr_id = aErs_packageattr_id and a.ers_shelfattr_id = shelfattrId;
-- 	-- 包装数量变化写入进仓单
-- 	if aErp_purch_bil_intoqty_id > 0 THEN
-- 		update erp_purch_bil_intoqty a
-- 		set a.packageQty = a.packageQty + 1, a.qty = a.qty + aQty
-- 		where a.id = aErp_purch_bil_intoqty_id;
-- 		if ROW_COUNT() <> 1 then
-- 			set msg = concat(msg, '未能同步修改进仓单明细');
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 		end if;
-- 	else
-- 		insert into erp_purch_bil_intoqty(erp_purch_bil_id, erp_purch_detail_id, goodsId, ers_packageattr_id
-- 			, roomId, ers_shelfattr_id, packageQty, qty
-- 			, inTime, inUserId, inEmpId, inEmpName)
-- 		select pid, pdid, aGoodsId, aErs_packageattr_id
-- 			, aRoomId, shelfattrId, 1, aQty
-- 			, now(), uId, eid, eName
-- 		;
-- 		if ROW_COUNT() <> 1 then
-- 			set msg = concat(msg, '未能同步新增进仓单明细！');
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 		ELSE
-- 			set aErp_purch_bil_intoqty_id = LAST_INSERT_ID();
-- -- SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = aErp_purch_bil_intoqty_id;
-- 		end if;
-- 	end if;

		-- 写入货架等信息
-- 		update erp_purchDetail_snCode a INNER JOIN id_temp b on a.id = b.id
-- 			set a.ers_shelfattr_id = shelfattrId, a.inUserId = uId, a.inEmpId = eId, a.inEmpName = eName
-- 				, a.inTime = CURRENT_TIMESTAMP()
-- 				, a.Erp_purch_bil_intoqty_id = aErp_purch_bil_intoqty_id;
-- 		if ROW_COUNT() = 0 THEN
-- 			set msg = concat(msg, '未能成功写入仓位信息！');
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 		end if;
	-- 给二维码写入货架、进仓单编号、进仓操作人等信息
	update erp_purchDetail_snCode a , erp_purchDetail_snCode b
			set a.ers_shelfattr_id = shelfattrId, a.roomId = aRoomId, a.state = 1
-- 				, a.erp_purch_bil_intoqty_id = aErp_purch_bil_intoqty_id
-- 				, a.inUserId = uId, a.inEmpId = eId, a.inEmpName = eName
-- 				, a.inTime = CURRENT_TIMESTAMP()
	where a.erp_purch_detail_id = b.erp_purch_detail_id -- and a.goodsId = b.goodsId 
			and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort
	;
	if ROW_COUNT() = 0 THEN
		set msg = concat(msg, '未能成功写入仓位！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	if not exists(	-- 该二维码对应的采购订单明细是否全部进仓完毕， 完毕登记最新供应商及最新进货价格
			select 1 from erp_purch_detail pd INNER JOIN erp_purchDetail_snCode a on pd.id = a.erp_purch_detail_id
			where pd.id = pdid and a.degree = 1 and a.state <> 1 limit 1 
		) then
		-- 登记最新供应商及最新进货价格
		call p_suppliersGoods_setPrice(
				pdErs_packageattr_id		-- 包裹ID
				, aDegree					-- 包裹层级
				, aGoodsId					-- 商品ID
				, aCrm_suppliers_id		-- 供应商ID
				, pdPrice					-- 进货价
		);
		if not exists(	-- 该二维码对应的采购订单是否全部明细进仓完毕， 完毕登记进仓人、修改采购订单进仓标志、并在采购流程表插入进仓完成（'flowaway'）流程
				select 1 from erp_purch_bil p INNER JOIN erp_purch_detail pd on p.id = pd.erp_purch_bil_id
					INNER JOIN erp_purchDetail_snCode a on pd.id = a.erp_purch_detail_id
				where p.id = pid and a.degree = 1 and a.state <> 1 limit 1 
			) then
			-- 修改采购订单主表的进仓人等信息
			update erp_purch_bil a set a.inTime = CURRENT_TIMESTAMP(), a.inUserId = uId, a.inEmpId = eId, a.inEmpName = eName
				, a.lastModifiedId = uId, a.lastModifiedEmpId = eid, a.lastModifiedEmpName = eName, a.lastModifiedBy = aUserName
			where a.id = pid;
			if ROW_COUNT() <> 1 THEN
					set msg = concat(msg, '入库完毕，未能成功修改进仓时间、进仓人！');
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;
			-- 修改相应销售单的isEnough = 1
			IF exists(SELECT 1 FROM erp_purch_detail b INNER JOIN erp_sales_detail a on a.id = b.erp_sales_detail_id
					WHERE b.erp_purch_bil_id = pid and a.isEnough = 0 limit 1
				) THEN 
				UPDATE erp_purch_detail b INNER JOIN erp_sales_detail a on a.id = b.erp_sales_detail_id
				set a.isEnough = 1
				where b.erp_purch_bil_id = pid and a.isEnough = 0;
				if ROW_COUNT() = 0 THEN
					set msg = concat(msg, '入库完毕，未能成功修改相应销售明细可以出仓标志！');
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
				end if;
				-- 修改相应销售单的可以出仓标志isSubmit = 1
				update erp_vendi_bil b INNER JOIN erp_purch_bil p on b.id = p.erp_vendi_bil_id
					set b.isSubmit = 1, b.lastModifiedId = uid
				where p.id = pid;
				if ROW_COUNT() = 0 THEN
					set msg = concat(msg, '入库完毕，未能成功修改相应销售单可以出仓标志！');
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
				end if;
			END IF;
		end if;
	end if;
end;;
DELIMITER ;