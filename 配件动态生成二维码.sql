-- *****************************************************************************************************
-- 创建存储过程 p_packageAttr_snCode, 根据包装动态生成二维码
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_packageAttr_snCode;
DELIMITER ;;
CREATE PROCEDURE `p_packageAttr_snCode`(
	aid bigint(20)	-- 采购明细表ID
, uId bigint(20)	-- 登陆用户ID
, pid bigint(20)	-- 包装ID
)
BEGIN

	declare iCount, aCount int;
	declare erp_purch_detail_id, gId, ers_packageAttr_id, aSupplierId, eid, puid BIGINT(20);
	DECLARE qty, degree, actualQty, childCount int;
	DECLARE str VARCHAR(10000);
	DECLARE msg VARCHAR(1000);
	DECLARE eName, eUserName VARCHAR(100);
	DECLARE aCheck TINYINT;

	-- 获取采购单供应商
	SELECT p.supplierId, p.isCheck, p.id into aSupplierId, aCheck, puid
	FROM erp_purch_detail pd
	INNER JOIN erp_purch_bil p ON p.id = pd.erp_purch_bil_id
	WHERE pd.id = aid;
	-- 根据采购单状态判断是否能生成二维码
	if isnull(puid) THEN
		set msg = concat('指定的采购订单（编号：', puid,'）不存在，不能完成生码操作');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;	
	ELSEIF aCheck <> 1 THEN
		set msg = concat('指定的采购订单（编号：', puid,'）没有审核通过，不能完成生码操作');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(aSupplierId) THEN
		set msg = concat('指定的采购订单（编号：', puid,'）没有指定供应商，不能完成生码操作');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF NOT EXISTS(SELECT 1 FROM ers_packageattr p WHERE p.id = pid) THEN
		set msg = concat('指定的包装信息不存在，不能完成生码操作');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 设置计数器
	set @xh = 0;
	-- 清空生码临时表
	delete from erp_purch_detail_temp;
	-- 写入生码临时表
	INSERT INTO erp_purch_detail_temp(id, erp_purch_detail_id, goodsId, ers_packageAttr_id, qty, degree)
	SELECT (@xh:=@xh+1) as id, aid, pd.goodsId, pid, p.degree
	FROM erp_purch_detail pd 
	INNER JOIN ers_packageattr p ON p.id = pid
	WHERE pd.id = aid;

	select max(id) into aCount from erp_purch_detail_temp;
	set str = '';
	while aCount > 0 DO
		select a.erp_purch_detail_id, a.goodsId, a.ers_packageAttr_id, a.qty, a.degree
		into erp_purch_detail_id, gId, ers_packageAttr_id, qty, degree
		from erp_purch_detail_temp a
		where a.id = aCount;
		set @nLevel = 0;

		while degree > 0 do
			select a.actualQty into actualQty from ers_packageAttr a where a.id = ers_packageAttr_id;
			if not(actualQty > 0) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '包装含的单品数量必须大于0！';
			end if;
			-- 生成select 字符串
			
			set str = concat(str, ' union all (select ', aid, ' ,', erp_purch_detail_id, ' ,', aSupplierId, ' ,'
				, ers_packageattr_id, ' ,', degree, ' ,'
				, @nLevel, ' ,'
				, actualQty, ' , id', ' ,', gId, ' from t_batchdata limit ', qty, ') ');
			set @nLevel = @nLevel + 1;
			set degree = degree - 1;
			if degree > 0 then
				select a.parentId, qty * a.childCount into ers_packageAttr_id, qty
				from ers_packageAttr a where a.id = ers_packageAttr_id;
			end if;
		end while;
		set aCount = aCount - 1;
	end while;
	set str = concat('insert into erp_purchDetail_snCode(erp_purch_bil_id, erp_purch_detail_id, supplierId, ers_packageattr_id'
			, ', degree, nLevel, qty, snCode, goodsId)', substr(str, 11));

		SET @sql1 = str;
		PREPARE stmt1 FROM @sql1;
		EXECUTE stmt1;
		DEALLOCATE PREPARE stmt1 ;

	-- 暂时没有扫码系统，自动生成包装的从属关系
	update erp_purchdetail_sncode a set a.sSort = concat(a.id, ',')
	where a.erp_purch_detail_id = aid and a.nLevel = 0;

	update erp_purchdetail_sncode a 
		INNER JOIN (
			SELECT a.id, a.ers_packageattr_id, a.erp_purch_detail_id, a.goodsId, a.degree
				, case when isnull(b.id) then null else ceiling(a.snCode/b.childCount) end as pId-- , b.*
			from erp_purchdetail_sncode a left JOIN ers_packageattr b on a.ers_packageattr_id = b.parentId
-- 			where a.erp_purch_detail_id = aid
			INNER JOIN erp_purch_detail pd on a.erp_purch_detail_id = pd.id
			INNER JOIN erp_purch_bil p on p.id = pd.erp_purch_bil_id
			where p.id = aId
	-- 		ORDER BY a.id asc
		) b on a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId 
				and a.degree - b.degree = 1 and a.snCode = b.pId
		INNER JOIN erp_purchdetail_sncode c on b.id = c.id
	set c.parentId = a.id;
	-- 获取当前用户信息
	call p_get_userInfo(uId, eid, eName, eUserName);
	-- 更新采购单主表
	UPDATE erp_purch_bil a 
	SET a.lastModifiedId = uId, a.sncodeTime = NOW()
	WHERE a.id = aid
	;
	-- 写入流程
	insert into erp_purch_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
			select aid, 'createCode', uId, eid, eName, eUserName, '配件生码';

	if ROW_COUNT() = 0 THEN
		set msg = concat('采购单（编号：', aid,'）通过审核时，生成二维码!');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
END;;
DELIMITER ;