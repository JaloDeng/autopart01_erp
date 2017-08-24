DROP TRIGGER IF EXISTS tr_erp_vendi_detail_BEFORE_UPDATE;

DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp_vendi_detail` FOR EACH ROW BEGIN
	if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.id and a.billStatus = 'submitthatview') then
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已提交审核，不能修改！';
	elseif exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.id and a.billStatus = 'checked') then
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已转为销售订单，不能修改！';
	elseif new.qty < 1 then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '未指定正确的数量，无法修改！';
	else
		if exists(select 1 from erp_inquiry_bil a where a.id = new.erp_inquiry_bil_id and a.isSubmit = 0) then  -- 客服修改询价明细
			if (new.price > 0 and (isnull(old.price) or new.price <> old.price)) THEN -- 修改了进价
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '客服不能修改进货价格！';
			end if;
			if new.salesPrice > 0 and (isnull(old.salesPrice) or new.salesPrice <> old.salesPrice > 0) then
				-- 如果客服修改了售价，需要进行售价有效性检查
				if uf_salesPrice_isValiad(new.goodsId, new.price, new.salesPrice) = 0 THEN
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '商品售价不符合调价规则！';
				end if;
			end if;
		ELSE -- 跟单
			if new.salesPrice > 0 and (isnull(old.salesPrice) or new.salesPrice <> old.salesPrice > 0) then
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '跟单不能修改销售价格！';
			end if;
			
			if (new.price > 0 and (isnull(old.price) or new.price <> old.price))  THEN -- 修改了进价, 需要重新计算售价
				set new.salesPrice = uf_salesPrice_calc(new.price);
			end if;
		end if;
		-- 计算销售金额及进货金额
		if new.price > 0 then set new.amt = new.qty * new.price; end if;
		if new.salesPrice > 0 then set new.salesAmt = new.qty * new.salesPrice; end if;
		-- 记录操作记录
		insert into erp_inquiry_bilwfw(billId, billstatus, userid, name, optime)
		SELECT new.id, 'selfupdated', a.creatorId, '自行修改', CURRENT_TIMESTAMP()
		from erp_inquiry_bil a;
	end if;
END;;
DELIMITER ;