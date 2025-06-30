import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // 既存データをチェック
  const existingProducts = await prisma.product.count();
  
  if (existingProducts > 0) {
    console.log(`Database already has ${existingProducts} products. Skipping seed.`);
    return;
  }

  // 初期データを作成
  const products = await prisma.product.createMany({
    data: [
      {
        name: 'iPhone 15',
        description: '最新のiPhone',
        price: 128000,
        stock: 10
      },
      {
        name: 'MacBook Pro',
        description: 'M3チップ搭載',
        price: 248000,
        stock: 5
      },
      {
        name: 'AirPods Pro',
        description: 'ノイズキャンセリング機能付き',
        price: 39800,
        stock: 20
      }
    ]
  });

  console.log(`Created ${products.count} products`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });