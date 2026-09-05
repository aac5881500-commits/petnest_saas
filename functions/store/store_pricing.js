// 檔案名稱：functions/store/store_pricing.js
// 功能說明：商城促銷計價（與 Flutter StorePricingService 對齊）
// 不改商品原價；同一層級取最優惠，不疊成連乘。
// 買 X 送 Y：付款數量與出貨數量分開。

/**
 * @param {Object} promo
 * @param {Date} now
 * @return {boolean}
 */
function isActiveAt(promo, now) {
  if (promo.enabled === false || promo.archived === true) {
    return false;
  }
  const start = toDate(promo.startAt);
  const end = toDate(promo.endAt);
  if (start && now < start) {
    return false;
  }
  if (end && now > end) {
    return false;
  }
  return true;
}

/**
 * @param {*} value
 * @return {Date|null}
 */
function toDate(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toDate === "function") {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  return null;
}

/**
 * @param {number} original
 * @param {string} method
 * @param {number} value
 * @return {number}
 */
function applyDiscount(original, method, value) {
  let result = original;
  const numValue = Number(value || 0);
  if (method === "percent") {
    result = Math.round(original * (numValue / 10));
    if (numValue > 10) {
      result = Math.round(original * (numValue / 100));
    }
  } else if (method === "amountOff" || method === "amount_off") {
    result = original - Math.round(numValue);
  } else if (method === "specialPrice" || method === "special_price") {
    result = Math.round(numValue);
  }
  return result < 0 ? 0 : result;
}

/**
 * @param {Object} product
 * @param {Date} now
 * @return {boolean}
 */
function isItemPromotionActive(product, now) {
  if (product.itemPromotionEnabled !== true) {
    return false;
  }
  const type = String(product.itemPromotionType || "none");
  if (type === "none") {
    return false;
  }
  const start = toDate(product.itemPromotionStartAt);
  const end = toDate(product.itemPromotionEndAt);
  if (start && now < start) {
    return false;
  }
  if (end && now > end) {
    return false;
  }
  return true;
}

/**
 * @param {number} value
 * @return {string}
 */
function percentLabel(value) {
  const numValue = Number(value || 0);
  if (numValue <= 10) {
    return `${String(numValue).replace(/\.0$/, "")}折`;
  }
  return `${Math.round(numValue)}折`;
}

/**
 * @param {Object} product
 * @param {Date} now
 * @return {string}
 */
function itemPromotionNameOf(product, now) {
  if (!isItemPromotionActive(product, now)) {
    return "";
  }
  const type = String(product.itemPromotionType || "");
  const value = Number(product.itemPromotionValue || 0);
  const buy = Math.max(1, Number(product.itemPromotionBuyQuantity || 1));
  const free = Math.max(1, Number(product.itemPromotionFreeQuantity || 1));
  if (type === "special_price") {
    return `特價 NT$${Math.round(value)}`;
  }
  if (type === "percent") {
    return percentLabel(value);
  }
  if (type === "amount_off") {
    return `每件折 NT$${Math.round(value)}`;
  }
  if (type === "buy_x_get_y") {
    return `買${buy}送${free}`;
  }
  return "";
}

/**
 * @param {Object} product
 * @param {number} original
 * @param {Date} now
 * @return {number}
 */
function applyItemUnitPrice(product, original, now) {
  if (!isItemPromotionActive(product, now)) {
    return original;
  }
  const type = String(product.itemPromotionType || "");
  const value = Number(product.itemPromotionValue || 0);
  if (type === "special_price") {
    return applyDiscount(original, "specialPrice", value);
  }
  if (type === "percent") {
    return applyDiscount(original, "percent", value);
  }
  if (type === "amount_off") {
    return applyDiscount(original, "amountOff", value);
  }
  return original;
}

/**
 * @param {Object} product
 * @param {number} purchase
 * @param {Date} now
 * @return {number}
 */
function freeQuantityOf(product, purchase, now) {
  if (!isItemPromotionActive(product, now)) {
    return 0;
  }
  if (String(product.itemPromotionType || "") !== "buy_x_get_y") {
    return 0;
  }
  const buy = Math.max(1, Number(product.itemPromotionBuyQuantity || 1));
  const free = Math.max(1, Number(product.itemPromotionFreeQuantity || 1));
  const qty = Math.max(0, Number(purchase || 0));
  return Math.floor(qty / buy) * free;
}

/**
 * @param {Object} promo
 * @param {string} productId
 * @param {string} categoryId
 * @return {boolean}
 */
function matchesProduct(promo, productId, categoryId) {
  const type = String(promo.type || "");
  const productIds = Array.isArray(promo.productIds) ?
    promo.productIds.map((item) => String(item)) :
    [];
  const promoCategory = String(promo.categoryId || "").trim();
  if (type === "storewide") {
    return true;
  }
  if (type === "product") {
    return productIds.includes(productId);
  }
  if (type === "category") {
    return Boolean(promoCategory) && promoCategory === categoryId;
  }
  if (type === "flash") {
    if (productIds.includes(productId)) {
      return true;
    }
    if (Boolean(promoCategory) && promoCategory === categoryId) {
      return true;
    }
    return productIds.length === 0 && !promoCategory;
  }
  return false;
}

/**
 * @param {Date|null} a
 * @param {Date|null} b
 * @return {Date|null}
 */
function earlierEnd(a, b) {
  if (!a) {
    return b || null;
  }
  if (!b) {
    return a;
  }
  return a < b ? a : b;
}

/**
 * @param {Object} candidate
 * @param {Object} current
 * @param {number} purchase
 * @return {boolean}
 */
function isBetterChoice(candidate, current, purchase) {
  const candidatePaid = candidate.paidUnit * purchase;
  const currentPaid = current.paidUnit * purchase;
  if (candidatePaid !== currentPaid) {
    return candidatePaid < currentPaid;
  }
  return candidate.freeQuantity > current.freeQuantity;
}

/**
 * @param {Object} params
 * @return {Object}
 */
function quoteProduct({product, productId, quantity, promotions, now}) {
  const purchase = Math.max(1, Number(quantity || 1));
  const original = Math.max(0, Number(product.price || 0));
  const itemActive = isItemPromotionActive(product, now);
  const itemUnit = applyItemUnitPrice(product, original, now);
  const itemFree = freeQuantityOf(product, purchase, now);
  const itemName = itemPromotionNameOf(product, now);
  const itemType = itemActive ?
    String(product.itemPromotionType || "none") :
    "none";
  const itemEnd = itemActive ? toDate(product.itemPromotionEndAt) : null;
  const itemDiscount = (original - itemUnit) * purchase;
  const choices = [];

  if (itemActive) {
    choices.push({
      paidUnit: itemUnit,
      freeQuantity: itemFree,
      itemPromotionType: itemType,
      itemPromotionName: itemName,
      itemPromotionDiscount: itemDiscount,
      campaignDiscount: 0,
      canStackFurther: product.itemPromotionAllowStack === true,
      campaign: null,
      appliedEndAt: itemEnd,
    });
  } else {
    choices.push({
      paidUnit: original,
      freeQuantity: 0,
      itemPromotionType: "none",
      itemPromotionName: "",
      itemPromotionDiscount: 0,
      campaignDiscount: 0,
      canStackFurther: true,
      campaign: null,
      appliedEndAt: null,
    });
  }

  const matching = promotions.filter((promo) => {
    const type = String(promo.type || "");
    return isActiveAt(promo, now) &&
      ["product", "category", "storewide", "flash"].includes(type) &&
      matchesProduct(promo, productId, String(product.categoryId || ""));
  });

  const lockItemBogo = itemActive &&
    product.itemPromotionAllowStack !== true &&
    String(product.itemPromotionType || "") === "buy_x_get_y";

  for (const campaign of matching) {
    if (lockItemBogo) {
      continue;
    }
    const campaignUnit = applyDiscount(
        original,
        String(campaign.discountMethod || ""),
        campaign.discountValue,
    );
    choices.push({
      paidUnit: campaignUnit,
      freeQuantity: 0,
      itemPromotionType: "none",
      itemPromotionName: "",
      itemPromotionDiscount: 0,
      campaignDiscount: (original - campaignUnit) * purchase,
      canStackFurther: campaign.allowStack === true,
      campaign,
      appliedEndAt: toDate(campaign.endAt),
    });

    if (itemActive &&
      product.itemPromotionAllowStack === true &&
      campaign.allowStack === true) {
      const stackedUnit = applyDiscount(
          itemUnit,
          String(campaign.discountMethod || ""),
          campaign.discountValue,
      );
      choices.push({
        paidUnit: stackedUnit,
        freeQuantity: itemFree,
        itemPromotionType: itemType,
        itemPromotionName: itemName,
        itemPromotionDiscount: itemDiscount,
        campaignDiscount: (itemUnit - stackedUnit) * purchase,
        canStackFurther: true,
        campaign,
        appliedEndAt: earlierEnd(itemEnd, toDate(campaign.endAt)),
      });
    }
  }

  let best = choices[0];
  for (let index = 1; index < choices.length; index += 1) {
    if (isBetterChoice(choices[index], best, purchase)) {
      best = choices[index];
    }
  }

  return {
    originalUnitPrice: original,
    finalUnitPrice: best.paidUnit,
    purchaseQuantity: purchase,
    freeQuantity: best.freeQuantity,
    fulfillmentQuantity: purchase + best.freeQuantity,
    itemPromotionType: best.itemPromotionType,
    itemPromotionName: best.itemPromotionName,
    itemPromotionDiscount: best.itemPromotionDiscount,
    campaignDiscount: best.campaignDiscount,
    canStackFurther: best.canStackFurther,
    promotion: best.campaign,
    appliedEndAt: best.appliedEndAt,
  };
}

/**
 * @param {Object} promo
 * @return {boolean}
 */
function isMixMatch(promo) {
  return String(promo.type || "") === "quantity" &&
    Array.isArray(promo.productIds) &&
    promo.productIds.length > 0;
}

/**
 * @param {Object} params
 * @return {Object}
 */
function quoteBundle({promotion, sets, productsById}) {
  const items = Array.isArray(promotion.bundleItems) ?
    promotion.bundleItems :
    [];
  let original = 0;
  const labels = [];
  for (const line of items) {
    const productId = String(line.productId || "");
    const qty = Math.max(1, Number(line.quantity || 1));
    const product = productsById[productId] || {};
    original += Math.max(0, Number(product.price || 0)) * qty * sets;
    labels.push(`${product.name || "商品"}×${qty}`);
  }
  const bundlePrice = Math.max(
      0,
      Math.round(Number(promotion.discountValue || 0)),
  );
  let finalTotal = bundlePrice * sets;
  if (finalTotal > original) {
    finalTotal = original;
  }
  return {
    promotion,
    sets,
    originalTotal: original,
    finalTotal,
    componentLabels: labels,
  };
}

/**
 * @param {Object} params
 * @return {Object}
 */
function quoteMixMatch({lines, promotions}) {
  let best = {discount: 0, promotion: null, productIds: []};
  for (const promo of promotions) {
    if (!isMixMatch(promo) || Number(promo.minimumQuantity || 0) <= 0) {
      continue;
    }
    const productIds = promo.productIds.map((id) => String(id));
    const eligible = lines.filter((line) => {
      return line.canStackFurther && productIds.includes(line.productId);
    });
    const qty = eligible.reduce((sum, line) => sum + line.purchaseQuantity, 0);
    if (qty < Number(promo.minimumQuantity || 0)) {
      continue;
    }
    const eligibleAmount = eligible.reduce(
        (sum, line) => sum + line.finalSubtotal,
        0,
    );
    let discounted = eligibleAmount;
    if (String(promo.discountMethod || "") === "specialPrice") {
      const minQty = Number(promo.minimumQuantity || 0);
      const groups = Math.floor(qty / minQty);
      const covered = groups * minQty;
      const units = [];
      eligible.forEach((line) => {
        for (let i = 0; i < line.purchaseQuantity; i += 1) {
          units.push(line.finalUnitPrice);
        }
      });
      units.sort((a, b) => b - a);
      let rest = 0;
      for (let i = covered; i < units.length; i += 1) {
        rest += units[i];
      }
      discounted = (groups *
        Math.round(Number(promo.discountValue || 0))) + rest;
    } else {
      discounted = applyDiscount(
          eligibleAmount,
          String(promo.discountMethod || ""),
          promo.discountValue,
      );
    }
    const saving = eligibleAmount - discounted;
    if (saving > best.discount) {
      best = {discount: Math.max(0, saving), promotion: promo, productIds};
    }
  }
  return best;
}

/**
 * @param {Object} params
 * @return {Object}
 */
function quoteCart({
  entries,
  promotions,
  now,
  bundleQuantities,
  extraProductsById,
}) {
  const active = promotions.filter((promo) => isActiveAt(promo, now));
  const lines = entries.map((entry) => {
    const quoted = quoteProduct({
      product: entry.product,
      productId: entry.productId,
      quantity: entry.quantity,
      promotions: active,
      now,
    });
    return {
      ...quoted,
      productId: entry.productId,
      quantity: quoted.purchaseQuantity,
      originalSubtotal: quoted.originalUnitPrice * quoted.purchaseQuantity,
      finalSubtotal: quoted.finalUnitPrice * quoted.purchaseQuantity,
    };
  });

  const originalSubtotal = lines.reduce(
      (sum, line) => sum + line.originalSubtotal,
      0,
  );
  const itemPromotionDiscount = lines.reduce(
      (sum, line) => sum + line.itemPromotionDiscount,
      0,
  );
  const campaignDiscount = lines.reduce(
      (sum, line) => sum + line.campaignDiscount,
      0,
  );

  const mix = quoteMixMatch({lines, promotions: active});
  let stackableAmount = 0;
  let lockedAmount = 0;
  let stackableQty = 0;
  for (const line of lines) {
    const mixLocked = mix.promotion &&
      mix.promotion.allowStack !== true &&
      mix.productIds.includes(line.productId);
    if (line.canStackFurther && !mixLocked) {
      stackableAmount += line.finalSubtotal;
      stackableQty += line.purchaseQuantity;
    } else {
      lockedAmount += line.finalSubtotal;
    }
  }
  if (mix.promotion && mix.promotion.allowStack === true) {
    stackableAmount = Math.max(0, stackableAmount - mix.discount);
  }

  const cartLayer = quoteCartLayers({
    promotions: active.filter((promo) => !isMixMatch(promo)),
    stackableAmount,
    stackableQty,
  });

  const productsById = Object.assign({}, extraProductsById || {});
  entries.forEach((entry) => {
    productsById[entry.productId] = entry.product;
  });
  const bundleQuotes = [];
  let bundleOriginal = 0;
  let bundleFinal = 0;
  const qtyMap = bundleQuantities || {};
  for (const promo of active) {
    const sets = Number(qtyMap[promo.id] || 0);
    if (String(promo.type || "") !== "bundle" || sets <= 0) {
      continue;
    }
    const quoted = quoteBundle({promotion: promo, sets, productsById});
    bundleQuotes.push(quoted);
    bundleOriginal += quoted.originalTotal;
    bundleFinal += quoted.finalTotal;
  }

  const mixLockedDiscount = mix.promotion && mix.promotion.allowStack !== true ?
    mix.discount :
    0;
  const productFinal = lockedAmount +
    cartLayer.finalStackable -
    mixLockedDiscount;
  const finalSubtotal = Math.max(0, productFinal + bundleFinal);

  return {
    lines,
    originalSubtotal: originalSubtotal + bundleOriginal,
    itemDiscount: itemPromotionDiscount + campaignDiscount,
    itemPromotionDiscount,
    campaignDiscount,
    quantityDiscount: cartLayer.quantityDiscount + mix.discount,
    amountDiscount: cartLayer.amountDiscount,
    bundleDiscount: bundleOriginal - bundleFinal,
    bundleQuotes,
    promotionDiscount: itemPromotionDiscount +
      campaignDiscount +
      cartLayer.quantityDiscount +
      mix.discount +
      cartLayer.amountDiscount +
      (bundleOriginal - bundleFinal),
    finalSubtotal,
    quantityPromotion: mix.promotion || cartLayer.quantityPromotion,
    amountPromotion: cartLayer.amountPromotion,
  };
}

/**
 * @param {Object} params
 * @return {Object}
 */
function quoteCartLayers({promotions, stackableAmount, stackableQty}) {
  if (stackableAmount <= 0) {
    return {
      finalStackable: 0,
      quantityDiscount: 0,
      amountDiscount: 0,
      quantityPromotion: null,
      amountPromotion: null,
    };
  }

  const qtyPromos = promotions.filter((promo) => {
    return promo.type === "quantity" &&
      Number(promo.minimumQuantity || 0) > 0 &&
      stackableQty >= Number(promo.minimumQuantity || 0);
  });
  const amountPromos = promotions.filter((promo) => {
    return promo.type === "amount" && Number(promo.minimumAmount || 0) > 0;
  });

  const qtyOnly = bestCartDiscount({
    promotions: qtyPromos,
    currentSubtotal: stackableAmount,
  });
  const amountOnly = bestCartDiscount({
    promotions: amountPromos.filter((promo) => {
      return stackableAmount >= Number(promo.minimumAmount || 0);
    }),
    currentSubtotal: stackableAmount,
  });

  let stackedAmount = null;
  if (qtyOnly && qtyOnly.promotion.allowStack === true) {
    stackedAmount = bestCartDiscount({
      promotions: amountPromos.filter((promo) => {
        return promo.allowStack === true &&
          qtyOnly.finalAmount >= Number(promo.minimumAmount || 0);
      }),
      currentSubtotal: qtyOnly.finalAmount,
    });
  }

  let bestAmount = stackableAmount;
  let quantityPromotion = null;
  let amountPromotion = null;
  let quantityDiscount = 0;
  let amountDiscount = 0;

  const consider = ({
    finalAmount,
    quantity,
    amount,
    nextQtyDiscount,
    nextAmountDiscount,
  }) => {
    if (finalAmount < bestAmount) {
      bestAmount = finalAmount;
      quantityPromotion = quantity;
      amountPromotion = amount;
      quantityDiscount = nextQtyDiscount;
      amountDiscount = nextAmountDiscount;
    }
  };

  if (qtyOnly) {
    consider({
      finalAmount: qtyOnly.finalAmount,
      quantity: qtyOnly.promotion,
      amount: null,
      nextQtyDiscount: stackableAmount - qtyOnly.finalAmount,
      nextAmountDiscount: 0,
    });
  }
  if (amountOnly) {
    consider({
      finalAmount: amountOnly.finalAmount,
      quantity: null,
      amount: amountOnly.promotion,
      nextQtyDiscount: 0,
      nextAmountDiscount: stackableAmount - amountOnly.finalAmount,
    });
  }
  if (qtyOnly && stackedAmount) {
    consider({
      finalAmount: stackedAmount.finalAmount,
      quantity: qtyOnly.promotion,
      amount: stackedAmount.promotion,
      nextQtyDiscount: stackableAmount - qtyOnly.finalAmount,
      nextAmountDiscount: qtyOnly.finalAmount - stackedAmount.finalAmount,
    });
  }

  return {
    finalStackable: bestAmount,
    quantityDiscount,
    amountDiscount,
    quantityPromotion,
    amountPromotion,
  };
}

/**
 * @param {Object} params
 * @return {{promotion: Object, finalAmount: number}|null}
 */
function bestCartDiscount({promotions, currentSubtotal}) {
  let best = null;
  for (const promo of promotions) {
    const method = String(promo.discountMethod || "") === "specialPrice" ?
      "amountOff" :
      String(promo.discountMethod || "");
    const priced = applyDiscount(currentSubtotal, method, promo.discountValue);
    if (!best || priced < best.finalAmount) {
      best = {promotion: promo, finalAmount: priced};
    }
  }
  return best;
}

module.exports = {
  applyDiscount,
  isActiveAt,
  quoteCart,
  quoteProduct,
  quoteBundle,
  freeQuantityOf,
};
