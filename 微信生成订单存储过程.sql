-- *****************************************************************************************************
-- 创建存储过程 p_wx_create_vendi_bil, 微信生成订单
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_wx_create_vendi_bil;
DELIMITER ;;
CREATE PROCEDURE p_wx_create_vendi_bil(
		gid bigint(20) -- 商品编号erp_goods.id
	, cid bigint(20) -- 客户编号autopart01_crm.erc$customer.id
	, tid bigint(20) -- 客户收货地址编号erc_customer_address.id
	, OUT iCode VARCHAR(100) -- 返回销售订单号
)
BEGIN

	DECLARE uId, sId, nId, packageId, aSupplierId BIGINT(20);
	DECLARE sName, aPackageUnit VARCHAR(100);
	DECLARE shipPrice, bPrice, sPrice DECIMAL(20,4);
	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;

	-- 开启事务
	START TRANSACTION;

	-- 获取用户信息
	SELECT u.ID, s.id, s.`name`	INTO uId, sId, sName
	FROM autopart01_security.`sec$user` u INNER JOIN autopart01_crm.`erc$staff` s ON s.userName = u.username
	WHERE u.username = 'weixin';
	-- 获取商品信息
	SELECT g.shippingPrice, p.id, g.price, p.packageUnit, p.newSupplierId, p.newPrice
	INTO shipPrice, packageId, bPrice, aPackageUnit, aSupplierId, sPrice
	FROM erp_goods_gift g 
	INNER JOIN ers_packageattr p ON p.goodsId = gid AND p.degree = 1
	WHERE g.goodsId = gid;
	
	-- 未创建'wenxin'用户报错
	IF ISNULL(uId) OR ISNULL(sId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '系统中未创建微信操作用户，请联系客服创建！';
	ELSEIF ISNULL(bPrice) OR ISNULL(packageId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '礼品不存在或已下架，请联系客服创建！';
	END IF;

	-- 新增销售订单表
	INSERT INTO erp_vendi_bil(customerId, creatorId, empId, empName
		, zoneNum, priceSumShip, createdDate, createdBy, costTime
		, lastModifiedDate, lastModifiedId, lastModifiedEmpId, lastModifiedEmpName, lastModifiedBy
		, erc$telgeo_contact_id)
	SELECT cid, uId, sId, sName
		, '86', IFNULL(shipPrice,0), NOW(), 'weixin', NOW()
		, NOW(), uId, sId, sName, 'weixin'
		, tid;
	if ROW_COUNT() <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增订单失败！';
	end if;
	-- 获取主表ID
	SET nId = LAST_INSERT_ID();

	-- 新增明细表
	INSERT INTO erp_sales_detail(erp_vendi_bil_id, ers_packageAttr_id, goodsId, supplierId, packageUnit
		, packageQty, packagePrice, price, amt
		, salesPackagePrice, qty, salesPrice, salesAmt
		, createdDate, lastModifiedDate, lastModifiedId, lastModifiedEmpId
		, lastModifiedEmpName, lastModifiedBy)
	SELECT nId, packageId, gid, aSupplierId, aPackageUnit
		, 1, sPrice, sPrice, sPrice
		, bPrice, 1, bPrice, bPrice
		,	NOW(), NOW(), uId, sId
		, sName, 'weixin';
	if ROW_COUNT() <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增订单失败！';
	end if;

	SELECT a.inquiryCode INTO iCode FROM erp_vendi_bil a WHERE a.id = nId;
	-- 提交
	COMMIT;
END;;
DELIMITER ;