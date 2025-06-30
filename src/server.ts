// src/server.ts
import express from 'express';
import { PrismaClient } from '@prisma/client';

const app = express();
const port = process.env.PORT || 3000;
const prisma = new PrismaClient();

app.use(express.json());

app.get('/health', (_, res: express.Response) => {
  res.send('OK');
});

app.get('/products', async (req, res) => {
  try {
    const products = await prisma.product.findMany();
    res.json(products);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

app.post('/products', async (req, res) => {
  try {
    const { name, description, price, stock } = req.body;
    const product = await prisma.product.create({
      data: {
        name,
        description,
        price,
        stock
      }
    });
    res.json(product);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create product' });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
