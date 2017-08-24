-- *****************************************************************************************************
-- 创建存储过程 p_vendiBack_snCode_shelfattr, 销售退货进仓
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_vendiBack_snCode_shelfattr;
DELIMITER ;;
CREATE PROCEDURE p_vendiBack_snCode_shelfattr(
	aid bigint(20) -- 货物二维码ID erp_purchDetail_snCode.id 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, shelfattrId bigint(20) -- 货架ID ers_packageAttr_id
	, vbdId BIGINT(20) -- 销售退货明细ID erp_vendi_back_detail.id
)
BEGIN

	DECLARE aEmpId, aRoomId, pdId, vbId, aGoodsId, bGoodsId, aErs_packageattr_id, aShelfbookId, sdId BIGINT(20);
	DECLARE aDegree, aQty, haveInQty, vbdQty INT;
	DECLARE aState, aSubmit TINYINT;
	DECLARE aEmpName, aUserName VARCHAR(100);
	DECLARE msg VARCHAR(1000);

	-- 判断用户是否合理
	IF NOT EXISTS(SELECT 1 FROM autopart01_security.sec$user a WHERE a.ID = uId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效用户操作核销出仓！';
	ELSE
		CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);
	END IF;

	-- 获取仓位的信息
	SELECT a.roomId INTO aRoomId FROM ers_shelfattr a WHERE a.id = shelfattrId;
	IF ISNULL(aRoomId) THEN
		SET msg = concat('指定的仓位（编号：', shelfattrId,'）不存在，不能完成进仓');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 获取货物原二维码信息
	SELECT a.erp_purch_detail_id, a.state, a.degree, a.ers_packageattr_id, a.qty, a.goodsId
	INTO pdId, aState, aDegree, aErs_packageattr_id, aQty, bGoodsId
	FROM erp_purchdetail_sncode a WHERE a.id = aid;
	-- 获取销售退货信息
	SELECT b.id, b.isSubmit, a.goodsId, a.qty, a.erp_sales_detail_id 
	INTO vbId, aSubmit, aGoodsId, vbdQty, sdId
	FROM erp_vendi_back_detail a 
	INNER JOIN erp_vendi_back b ON b.id = a.erp_vendi_back_id WHERE a.id = vbdId;
	-- 获取对应销售退货明细的进仓明细数量
	SET haveInQty = IFNULL((SELECT SUM(a.qty) FROM erp_vendi_back_intoqty a 
			WHERE a.erp_vendi_back_detail_id = vbdId AND a.goodsId = aGoodsId
		), 0);
	-- 判断该销售退货明细已经进仓的单品数量 + 指定二维码的单品数量 是否超出 该销售退货明细实际需要进仓的单品数量
	IF haveInQty = vbdQty THEN
		set msg = concat('已超出指定的销售退货明细（编号：', vbId,'）配件（编号：', aGoodsId,'）销售退货单品进仓数量（', vbdQty,'）！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aQty + haveInQty > vbdQty THEN
		set msg = concat('指定的销售退货明细（编号：', vbId,'）配件（编号：', aGoodsId,'）销售退货单品数量（'
			, vdvbdQtyQty,'）小于指定的二维码（编号：', aid,'）配件包装单品数量（', aQty
			,'）与已经出仓的单品数量（', haveOutQty,'）之和，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	
	-- 根据二维码表中相关信息判断能否进行销售退货进仓
	IF ISNULL(pdId) OR pdId < 1 THEN
		set msg = concat('指定的配件二维码（编号：', aid,'）不存在，不能完成进仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(bGoodsId) OR bGoodsId < 1 THEN
		set msg = concat('指定的配件二维码（编号：', aid,'）不存在，不能完成进仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(aGoodsId) OR aGoodsId < 1 THEN
		set msg = concat('输入销售退货明细（编号：', vbdId, '）不存在，不能完成进仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aGoodsId <> bGoodsId THEN
		set msg = concat('指定的配件二维码（编号：', aid,'）与销售退货明细的配件不对应，不能完成进仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aState <> -1 THEN
		set msg = concat('指定的配件二维码（编号：', aid, '，商品编号：', bGoodsId,'）还没销售卖出，不能完成进仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aSubmit <> 1 THEN
		set msg = concat('销售退货单（编号：', vbId, '）指定的配件二维码（编号：', aid
			, '，商品编号：', bGoodsId,'）仓库还没有签收，不能完成进仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	-- 判断是否存在对应的销售出仓单明细
	IF NOT EXISTS(SELECT 1 FROM erp_vendi_bil_goutqty a 
		WHERE a.erp_purchDetail_snCode_id = aid AND a.erp_sales_detail_id = sdId) THEN
			set msg = concat('销售退货单（编号：', vbId, '）指定的配件二维码（编号：', aid
				, '，商品编号：', bGoodsId,'）与销售订单（编号：', vbId, '）出仓明细不对应，不能完成进仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	-- 判断二维码是否可以进仓/整体进仓
	IF EXISTS(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.state <> -1
			and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
		if aDegree > 1 then
			set msg = concat('指定的配件二维码（编号：', aid,'）存在已经进仓或没有采购进仓的低级包装的记录，不能进行整体进仓！');
		else
			set msg = concat('指定的配件二维码（编号：', aid,'）已经进仓或没有采购进仓，不能再次进仓！');
		end if;
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	
	-- 写入销售退货进仓单
	insert into erp_vendi_back_intoqty(erp_purchDetail_snCode_id, erp_vendi_back_id, erp_vendi_back_detail_id
			, goodsId, ers_packageattr_id, roomId, ers_shelfattr_id, packageQty, qty
			, inTime, inUserId, inEmpId, inEmpName)
		select aid, vbId, vbdId
			, aGoodsId, aErs_packageattr_id, aRoomId, shelfattrId, 1, aQty
			, now(), uId, aEmpId, aEmpName
		;
	if ROW_COUNT() <> 1 then
		set msg = concat(msg, '未能同步新增销售退货进仓单明细！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 获取仓位账簿id
	SELECT a.id INTO aShelfbookId FROM ers_shelfbook a WHERE a.ers_packageattr_id = aErs_packageattr_id AND a.ers_shelfattr_id = shelfattrId;

	-- 更改货物二维码表的仓库、仓位、标志属性
	update erp_purchDetail_snCode a , erp_purchDetail_snCode b
			set a.ers_shelfattr_id = shelfattrId, a.roomId = aRoomId, a.state = 1, a.stockState = 0, a.ers_shelfbook_id = aShelfbookId
	where a.erp_purch_detail_id = b.erp_purch_detail_id AND a.state = -1
			and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort
	;
	if ROW_COUNT() = 0 THEN
		set msg = concat(msg, '未能成功写入仓位！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 记录操作
	insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select vbId, 'in', uId, aEmpId, aEmpName, aUserName
			, CONCAT('指定的配件二维码（编号：', aid, '，商品编号：', bGoodsId, '）进仓完成！！');
	if ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '入库完毕，未能记录操作！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 再次获取对应销售退货明细的进仓明细数量
	SET haveInQty = IFNULL((SELECT SUM(a.qty) FROM erp_vendi_back_intoqty a 
			WHERE a.erp_vendi_back_detail_id = vbdId AND a.goodsId = aGoodsId
		), 0);
	-- 判断该明细配件数量是否全部进仓
	IF vbdQty = haveInQty THEN
		-- 修改销售退货明细进仓时间
		UPDATE erp_vendi_back_detail vbd SET vbd.inTime = NOW(), vbd.lastModifiedId = uId WHERE vbd.id = vbdId;
		if ROW_COUNT() <> 1 THEN
				set msg = concat(msg, '入库完毕，未能成功修改进仓明细（编号：', vbdId, '）时间！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
		-- 判断同一销售退货单所有明细配件是否全部进仓
		if not exists(
			SELECT 1 FROM erp_vendi_back_detail v,	
				(SELECT a.id, IFNULL(SUM(c.qty), 0) AS sQty FROM erp_vendi_back_detail a
					INNER JOIN erp_vendi_back_detail b ON b.erp_vendi_back_id = a.erp_vendi_back_id
					LEFT JOIN erp_vendi_back_intoqty c ON c.erp_vendi_back_detail_id = a.id 
					WHERE b.id = vbdId GROUP BY a.id
				) b WHERE b.id = v.id AND v.qty > b.sQty LIMIT 1
		) then

			-- 修改销售退货单主表的进仓人等信息
			UPDATE erp_vendi_back a
			SET a.inTime = NOW(), a.lastModifiedId = uId
			WHERE a.id = vbId;
			if ROW_COUNT() <> 1 THEN
					set msg = concat(msg, '入库完毕，未能成功修改进仓时间、进仓人！');
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;

			-- 记录操作记录
			insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
			select vbId, 'allIn', uId, aEmpId, aEmpName, aUserName, '全部配件进仓完成';
			if ROW_COUNT() <> 1 THEN
					set msg = concat(msg, '入库完毕，未能记录操作！');
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;

		end if;
	END IF;

END;;
DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_call_vendiBack_snCode_shelf, 销售退货进仓
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_call_vendiBack_snCode_shelf;
DELIMITER ;;
CREATE PROCEDURE `p_call_vendiBack_snCode_shelf`(
	aids VARCHAR(65535) CHARSET latin1 -- 货物二维码ID erp_purchDetail_snCode.id(集合，用xml格式) 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, shelfattrId bigint(20) -- 新货架ID ers_packageAttr_id
	, vbdId BIGINT(20) -- 销售退货明细ID erp_vendi_back_detail.id
	, qty INT(11) -- 二维码个数
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
		CALL p_vendiBack_snCode_shelfattr(ExtractValue(aids, '//a[$i]'), uId, shelfattrId, vbdId);
		SET i = i+1;
	END WHILE;

	COMMIT;  

END;;
DELIMITER ;


-- *****************************************************************************************************
-- 创建存储过程 p_purchBack_snCode_shelfattr, 采购退货出仓
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_purchBack_snCode_shelfattr;
DELIMITER ;;
CREATE PROCEDURE p_purchBack_snCode_shelfattr(
	aid bigint(20) -- 货物二维码ID erp_purchDetail_snCode.id 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, pbdId BIGINT(20) -- 采购退货明细ID erp_purch_back_detail.id
)
BEGIN

	DECLARE aEmpId, aRoomId, pbId, aGoodsId, aErs_packageattr_id, pbdErs_packageAttr_id, aShelfId, pbdGoodsId BIGINT(20);
	DECLARE aDegree, aQty, pbdPackageQty, pbdQty, pbdDegree, haveOutQty INT;
	DECLARE aState, aStockState, vbCheck TINYINT;
	DECLARE aEmpName, aUserName VARCHAR(100);
	DECLARE msg VARCHAR(1000);
	DECLARE pbdOTime datetime;

	-- 判断用户是否合理
	IF NOT EXISTS(SELECT 1 FROM autopart01_security.sec$user a WHERE a.ID = uId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效用户操作核销出仓！';
	ELSE
		CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);
	END IF;

	-- 获取二维码的相关信息
	select a.goodsId, a.ers_packageattr_id, a.qty, a.ers_shelfattr_id, s.roomId, a.degree, a.state, a.stockState
	into aGoodsId, aErs_packageattr_id, aQty, aShelfId, aRoomId, aDegree, aState, aStockState
	from erp_purchDetail_snCode a INNER JOIN ers_shelfattr s on s.id = a.ers_shelfattr_id
	where a.id = aid;
	-- 根据二维码信息判断是否能出仓
	if isnull(aGoodsId) then
		set msg = concat('指定的配件二维码（编号：', aid,'）不存在，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif aState <> 1 THEN
		set msg = concat('指定的配件（编号：', aGoodsId,'）二维码（编号：', aid,'）尚未进仓或已经出仓，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aStockState <> 0 THEN
		set msg = concat('指定的配件（编号：', aGoodsId,'）二维码（编号：', aid,'）已备货，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif isnull(aRoomId) THEN
		set msg = concat('登记的二维码的仓位（编号：', aShelfId,'）不存在，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 获取采购退货明细相关信息
	SELECT pb.id, pbd.ers_packageAttr_id, pbd.packageQty, pbd.qty, pbd.goodsId, pbd.outTime, p.degree, pb.isCheck
	INTO pbId, pbdErs_packageAttr_id, pbdPackageQty, pbdQty, pbdGoodsId, pbdOTime, pbdDegree, vbCheck
	FROM erp_purch_back_detail pbd
	INNER JOIN erp_purch_back pb ON pb.id = pbd.erp_purch_back_id
	INNER JOIN ers_packageattr p ON p.id = pbd.ers_packageAttr_id
	WHERE pbd.id = pbdId
	;
	-- 根据采购退货明细信息判断是否能出仓
	if isnull(pbId) THEN
		set msg = concat('指定的采购退货单明细（编号：', pbdId,'）不存在，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF vbCheck <> 1 THEN
		set msg = concat('指定的采购退货单明细（编号：', pbdId,'）没有审核通过，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aGoodsId <> pbdGoodsId THEN
		set msg = concat('指定的采购退货单明细（编号：', pbdId,'）配件与指定的二维码（编号：'
			, aid,'）对应的配件（编号：', aGoodsId,'）不匹配，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif aDegree > pbdDegree THEN
		set msg = concat('指定的采购退货单明细（编号：', pbdId,'）配件包装级别（', pbdDegree, '）低于指定的二维码（编号：'
			, aid,'）配件包装级别（', aDegree,'），不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 判断二维码或低级包装中二维码是否已出仓
	if exists(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.state = -1
			and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该配件包装存在已经出仓的记录，不能进行整体出仓';
	end if;
	-- 判断二维码或低级包装中二维码是否已备货
	if exists(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.stockState = 1
			and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该配件包装存在已经备货，不能进行整体出仓';
	end if;
	-- 判断二维码或低级包装中二维码是否处于核销状态
	IF EXISTS(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_goods_cancel_detail c 
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId
			and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort AND c.erp_purchDetail_snCode_id = a.id LIMIT 1) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该配件包装处于核销状态或已核销出仓，不能进行整体出仓！';
	END IF;

	-- 获取该采购退货明细已出仓数量
	SET haveOutQty = IFNULL((SELECT SUM(a.qty) FROM erp_purch_back_goutqty a WHERE a.erp_purch_back_detail_id = pbdId AND a.goodsId = aGoodsId), 0);
	-- 判断已经出仓数量是否大于采购退货单明细数量
	if pbdQty = haveOutQty THEN
		set msg = concat('指定的采购退货单明细（编号：', pbdId,'）配件（编号：', aGoodsId,'）单品数量（', pbdQty,'）已经全部出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif aQty + haveOutQty > pbdQty THEN
		set msg = concat('指定的采购退货单明细（编号：', pbdId,'）配件（编号：', aGoodsId,'）单品数量（', pbdQty,'）小于指定的二维码（编号：'
			, aid,'）配件包装单品数量（', aQty,'）与已经出仓的单品数量（', haveOutQty,'）之和，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 根据二维码所在shelfBook位置判断是否需要拆包
	IF NOT EXISTS(SELECT 1 FROM erp_purchdetail_sncode a
		INNER JOIN ers_shelfbook b ON b.id = a.ers_shelfbook_id AND a.ers_packageattr_id = b.ers_packageattr_id
		WHERE a.id = aid) THEN

		call p_snCode_unpack(aid);

	END IF;

	-- 写入采购退货出仓单明细
	set msg = concat('配件（编号：', aGoodsId,'）二维码（编号', aid,'）库房（编号', aRoomId, '）仓位（编号：', aShelfId,'）出仓时，');
	insert into erp_purch_back_goutqty(erp_purchdetail_sncode_id, erp_purch_back_id, erp_purch_back_detail_id
			, goodsId, ers_packageattr_id, roomId, ers_shelfattr_id, packageQty, qty
			, outTime, outUserId, outEmpId, outEmpName)
		select aid, pbId, pbdId
			, aGoodsId, aErs_packageattr_id, aRoomId, aShelfId, 1, aQty
			, now(), uId, aEmpId, aEmpName
		;
	if ROW_COUNT() <> 1 THEN
		set msg = concat(msg, '未能同步新增采购出仓单明细！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 修改二维码的标志为-1（出仓），修改仓位账簿编号值为-1
	update erp_purchDetail_snCode a , erp_purchDetail_snCode b 
	set a.state = -1, a.ers_shelfbook_id = -1
	where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId 
			and b.id = aid and b.sSort = left(a.sSort, CHAR_LENGTH(b.sSort))
	;
	if ROW_COUNT() = 0 THEN
		set msg = concat(msg, '未能成功写入二维码出仓标志！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 再次获取该采购退货明细已出仓数量
	SET haveOutQty = IFNULL((SELECT SUM(a.qty) FROM erp_purch_back_goutqty a WHERE a.erp_purch_back_detail_id = pbdId AND a.goodsId = aGoodsId), 0);
	-- 判断采购退货出仓明细是否全部出仓
	IF pbdQty = haveOutQty THEN
		-- 更新采购退货明细出仓完成时间
		UPDATE erp_purch_back_detail a SET a.outTime = NOW(), a.lastModifiedId = uId WHERE a.id = pbdId;
		if ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '出仓完毕，未能成功修改采购退货明细出仓时间！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
		-- 对应采购退货单中所有明细是否全部出仓
		IF NOT EXISTS(SELECT 1 FROM erp_purch_back_detail pbd, 
			(
				SELECT a.id, IFNULL(SUM(g.qty),0) AS oQty FROM erp_purch_back_detail a
				INNER JOIN erp_purch_back_detail b ON b.erp_purch_back_id = a.erp_purch_back_id
				LEFT JOIN erp_purch_back_goutqty g ON g.erp_purch_back_detail_id = a.id
				WHERE b.id = pbdId GROUP BY a.id
			) b WHERE b.id = pbd.id AND pbd.qty > b.oQty LIMIT 1
		) THEN

			-- 修改采购退货单主表出仓信息
			UPDATE erp_purch_back a	SET a.outTime = NOW(), a.lastModifiedId = uId WHERE a.id = pbId;
			if ROW_COUNT() <> 1 THEN
				set msg = concat(msg, '出仓完毕，未能成功修改出仓时间！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;

		END IF;
	END IF;

END;;
DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_call_purchBack_snCode_shelf, 采购退货出仓
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_call_purchBack_snCode_shelf;
DELIMITER ;;
CREATE PROCEDURE `p_call_purchBack_snCode_shelf`(
	aids VARCHAR(65535) CHARSET latin1 -- 货物二维码ID erp_purchDetail_snCode.id(集合，用xml格式) 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, pbdId BIGINT(20) -- 采购退货明细ID erp_purch_back_detail.id
	, qty INT(11) -- 进仓商品个数
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
		CALL p_purchBack_snCode_shelfattr(ExtractValue(aids, '//a[$i]'), uId, pbdId);
		SET i = i+1;
	END WHILE;

	COMMIT;  

END;;
DELIMITER ;