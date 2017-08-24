DROP PROCEDURE IF EXISTS p_snCode_unpack;
DELIMITER ;;
CREATE PROCEDURE `p_snCode_unpack`(aid	bigint(20))
begin
	DECLARE msg VARCHAR(1000);
	DECLARE sbid, aPackageId BIGINT(20);
	DECLARE aQty INT;

		-- 获取当前二维码处于仓位账簿记录中的信息
		SELECT a.id, a.ers_packageattr_id, p.actualQty INTO sbid, aPackageId, aQty 
		FROM ers_shelfbook a 
		INNER JOIN erp_purchdetail_sncode b ON b.ers_shelfbook_id = a.id
		INNER JOIN ers_packageattr p ON p.id = a.ers_packageattr_id
		where b.id = aid;

		-- 拆包，修改仓位账簿的数量
		UPDATE ers_shelfbook a 
		set a.packageQty = a.packageQty - 1, a.qty = a.qty - aQty
		where a.id = sbid;
		if ROW_COUNT() <> 1 THEN
			set msg = concat('未能同步修改需要拆包的仓位账簿！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
		
		-- 插入sid拆包后的分包装到二维码拆包记录表
		TRUNCATE table erp_snCode_unpack;
		insert into erp_snCode_unpack(sncodeId, goodsId, ers_packageattr_id, roomId, ers_shelfattr_id, packageQty, qty)
			select b.id, b.goodsId, b.ers_packageattr_id, b.roomId, b.ers_shelfattr_id, 1 as packageQty, b.qty
			from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_purchDetail_snCode c
			where a.id = b.parentId and c.id = aid 
				and b.nLevel <= c.nLevel
				and locate(a.sSort, c.sSort) > 0 and locate(b.sSort, c.sSort) = 0
				and a.state = 1
				and b.ers_shelfbook_id > 0
				and b.ers_packageattr_id < aPackageId
			union all
			select a.id, a.goodsId, a.ers_packageattr_id, a.roomId, a.ers_shelfattr_id, 1 as packageQty, a.qty
			from erp_purchDetail_snCode a where a.id = aid 
		;
		if ROW_COUNT() = 0 THEN
			set msg = concat('未能同步新增二维码拆包记录！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;

		-- 更新二维码表的仓位账簿ID
		CALL p_sncode_unpack_set_shelfbook(aid);

end;;
DELIMITER ;