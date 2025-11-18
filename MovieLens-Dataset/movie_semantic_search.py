#!/usr/bin/env python3
# -*- coding:utf-8 -*-

"""
电影语义搜索系统 - 基于 Sentence-BERT + FAISS + 情感分析

Usage:
  # 1. 构建索引
  python movie_semantic_search.py \
      --mode build \
      --data_path movies_with_overview.csv \
      --index_path movie_index.faiss \
      --metadata_path movie_metadata.pkl

  # 2. 搜索
  python movie_semantic_search.py \
      --mode search \
      --query "一个关于友情的温馨的电影" \
      --index_path movie_index.faiss \
      --metadata_path movie_metadata.pkl \
      --top_k 10
"""

import argparse
import pandas as pd
import numpy as np
import faiss
import pickle
import re
from typing import List, Dict, Tuple
from tqdm import tqdm

# 模型导入
from sentence_transformers import SentenceTransformer
from transformers import pipeline

# BM25 (可选)
try:
	from rank_bm25 import BM25Okapi

	BM25_AVAILABLE = True
except:
	BM25_AVAILABLE = False
	print("Warning: rank-bm25 not installed. BM25 scoring disabled.")


class MovieSearchEngine:
	"""电影语义搜索引擎"""

	def __init__(
			self,
			embedding_model: str = "./models/paraphrase-multilingual-MiniLM-L12-v2",
			sentiment_model: str = "./models/twitter-xlm-roberta-base-sentiment",
			use_bm25: bool = True,
			alpha: float = 0.7,  # 语义相似度权重
			beta: float = 0.2,  # 情感匹配度权重
			gamma: float = 0.1  # BM25 权重
	):
		print("Initializing MovieSearchEngine...")

		# 1. 语义向量模型 (Sentence-BERT)
		print(f"Loading embedding model: {embedding_model}")
		self.encoder = SentenceTransformer(embedding_model)
		self.embed_dim = self.encoder.get_sentence_embedding_dimension()

		# 2. 情感分析模型
		print(f"Loading sentiment model: {sentiment_model}")
		self.sentiment_analyzer = pipeline(
			"sentiment-analysis",
			model=sentiment_model,
			top_k=None  # 返回所有标签的概率
		)

		# 3. BM25 (可选)
		self.use_bm25 = use_bm25 and BM25_AVAILABLE
		self.bm25 = None

		# 4. 权重参数
		self.alpha = alpha
		self.beta = beta
		self.gamma = gamma if self.use_bm25 else 0.0

		# 归一化权重
		total = self.alpha + self.beta + self.gamma
		self.alpha /= total
		self.beta /= total
		self.gamma /= total

		# 5. 索引和元数据
		self.faiss_index = None
		self.movies_df = None
		self.movie_texts = []  # 用于 BM25

		print(f"✓ Engine initialized (α={self.alpha:.2f}, β={self.beta:.2f}, γ={self.gamma:.2f})")

	def preprocess_text(self, text: str) -> str:
		"""文本清洗与预处理"""
		if pd.isna(text) or text == "":
			return ""

		# 1. 转小写
		text = text.lower()

		# 2. 移除特殊字符（保留中英文、数字、空格）
		text = re.sub(r'[^\w\s\u4e00-\u9fff]', ' ', text)

		# 3. 多空格合并
		text = re.sub(r'\s+', ' ', text).strip()

		return text

	def build_text_representation(self, row) -> str:
		"""构建电影的文本表示（用于向量化）"""
		parts = []

		# 标题（权重高，重复2次）
		title = self.preprocess_text(str(row.get('title', '')))
		if title:
			parts.extend([title] * 2)

		# 类型
		genres = self.preprocess_text(str(row.get('genres', '')))
		if genres:
			parts.append(genres)

		# 概述（最重要）
		overview = self.preprocess_text(str(row.get('overview', '')))
		if overview:
			parts.extend([overview] * 3)  # 重复3次增加权重

		return " ".join(parts)

	def extract_sentiment_features(self, text: str) -> Dict[str, float]:
		"""提取情感特征（正面/负面/中性）"""
		if not text:
			return {"positive": 0.33, "neutral": 0.34, "negative": 0.33}

		try:
			# 限制文本长度（模型限制）
			text = text[:512]
			results = self.sentiment_analyzer(text)[0]

			# 构建情感字典
			sentiment_dict = {item['label']: item['score'] for item in results}

			# 标准化标签（不同模型标签可能不同）
			normalized = {}
			for label, score in sentiment_dict.items():
				label_lower = label.lower()
				if 'pos' in label_lower:
					normalized['positive'] = score
				elif 'neg' in label_lower:
					normalized['negative'] = score
				else:
					normalized['neutral'] = score

			return normalized
		except Exception as e:
			print(f"Sentiment analysis error: {e}")
			return {"positive": 0.33, "neutral": 0.34, "negative": 0.33}

	def build_index(self, df: pd.DataFrame):
		"""构建 FAISS 索引"""
		print("\n=== Building Movie Search Index ===")
		self.movies_df = df.copy()

		# 1. 构建文本表示
		print("Building text representations...")
		texts = []
		for _, row in tqdm(df.iterrows(), total=len(df)):
			text = self.build_text_representation(row)
			texts.append(text)
		self.movie_texts = texts

		# 2. 生成语义向量
		print("Generating semantic embeddings...")
		embeddings = self.encoder.encode(
			texts,
			show_progress_bar=True,
			batch_size=32,
			convert_to_numpy=True
		)

		# 3. 构建 FAISS 索引
		print("Building FAISS index...")
		self.faiss_index = faiss.IndexFlatIP(self.embed_dim)  # 内积（余弦相似度）

		# 归一化向量（用于余弦相似度）
		faiss.normalize_L2(embeddings)
		self.faiss_index.add(embeddings.astype('float32'))

		# 4. 提取情感特征
		print("Extracting sentiment features...")
		sentiment_features = []
		for text in tqdm(texts):
			sentiment = self.extract_sentiment_features(text)
			sentiment_features.append(sentiment)

		self.movies_df['sentiment_positive'] = [s['positive'] for s in sentiment_features]
		self.movies_df['sentiment_neutral'] = [s['neutral'] for s in sentiment_features]
		self.movies_df['sentiment_negative'] = [s['negative'] for s in sentiment_features]

		# 5. 构建 BM25 索引（可选）
		if self.use_bm25:
			print("Building BM25 index...")
			tokenized_corpus = [text.split() for text in texts]
			self.bm25 = BM25Okapi(tokenized_corpus)

		print(f"✓ Index built: {len(df)} movies indexed")

	def search(
			self,
			query: str,
			top_k: int = 10,
			sentiment_boost: Dict[str, float] = None
	) -> List[Dict]:
		"""
		搜索电影

		Args:
			query: 用户查询
			top_k: 返回前K个结果
			sentiment_boost: 情感偏好 {"positive": 1.0, "neutral": 0.0, "negative": -0.5}
		"""
		if self.faiss_index is None:
			raise ValueError("Index not built! Call build_index() first.")

		print(f"\n=== Searching: '{query}' ===")

		# 1. 文本预处理
		query_clean = self.preprocess_text(query)

		# 2. 查询情感分析
		query_sentiment = self.extract_sentiment_features(query)
		print(f"Query sentiment: {query_sentiment}")

		# 3. 语义向量检索
		query_embedding = self.encoder.encode([query], convert_to_numpy=True)
		faiss.normalize_L2(query_embedding)

		# 检索候选集（Top-K * 3，后续重排序）
		candidate_k = min(top_k * 3, len(self.movies_df))
		semantic_scores, indices = self.faiss_index.search(
			query_embedding.astype('float32'),
			candidate_k
		)
		semantic_scores = semantic_scores[0]
		indices = indices[0]

		# 4. BM25 评分（可选）
		bm25_scores = np.zeros(len(indices))
		if self.use_bm25 and self.bm25:
			query_tokens = query_clean.split()
			all_bm25_scores = self.bm25.get_scores(query_tokens)
			bm25_scores = all_bm25_scores[indices]
			# 归一化到 [0, 1]
			if bm25_scores.max() > 0:
				bm25_scores = bm25_scores / bm25_scores.max()

		# 5. 情感匹配评分
		sentiment_scores = []
		for idx in indices:
			movie_sentiment = {
				'positive': self.movies_df.iloc[idx]['sentiment_positive'],
				'neutral': self.movies_df.iloc[idx]['sentiment_neutral'],
				'negative': self.movies_df.iloc[idx]['sentiment_negative']
			}

			# 情感相似度（余弦相似度）
			if sentiment_boost:
				# 用户指定情感偏好
				score = sum(
					movie_sentiment.get(k, 0) * v
					for k, v in sentiment_boost.items()
				)
			else:
				# 自动匹配查询情感
				score = sum(
					query_sentiment.get(k, 0) * movie_sentiment.get(k, 0)
					for k in ['positive', 'neutral', 'negative']
				)
			sentiment_scores.append(score)

		sentiment_scores = np.array(sentiment_scores)

		# 6. 融合评分
		final_scores = (
				self.alpha * semantic_scores +
				self.beta * sentiment_scores +
				self.gamma * bm25_scores
		)

		# 7. 重排序并返回 Top-K
		top_indices = np.argsort(final_scores)[::-1][:top_k]

		results = []
		for rank, i in enumerate(top_indices, 1):
			idx = indices[i]
			movie = self.movies_df.iloc[idx]

			results.append({
				'rank': rank,
				'movieId': movie.get('movieId', ''),
				'title': movie.get('title', ''),
				'genres': movie.get('genres', ''),
				'overview': movie.get('overview', '')[:200] + '...',
				'scores': {
					'final': float(final_scores[i]),
					'semantic': float(semantic_scores[i]),
					'sentiment': float(sentiment_scores[i]),
					'bm25': float(bm25_scores[i])
				},
				'sentiment': {
					'positive': float(movie['sentiment_positive']),
					'neutral': float(movie['sentiment_neutral']),
					'negative': float(movie['sentiment_negative'])
				}
			})

		return results

	def save_index(self, index_path: str, metadata_path: str):
		"""保存索引和元数据"""
		print(f"Saving index to {index_path}...")
		faiss.write_index(self.faiss_index, index_path)

		metadata = {
			'movies_df': self.movies_df,
			'movie_texts': self.movie_texts,
			'bm25': self.bm25,
			'config': {
				'alpha': self.alpha,
				'beta': self.beta,
				'gamma': self.gamma,
				'embed_dim': self.embed_dim
			}
		}

		with open(metadata_path, 'wb') as f:
			pickle.dump(metadata, f)

		print("✓ Index saved")

	def load_index(self, index_path: str, metadata_path: str):
		"""加载索引和元数据"""
		print(f"Loading index from {index_path}...")
		self.faiss_index = faiss.read_index(index_path)

		with open(metadata_path, 'rb') as f:
			metadata = pickle.load(f)

		self.movies_df = metadata['movies_df']
		self.movie_texts = metadata['movie_texts']
		self.bm25 = metadata['bm25']

		config = metadata['config']
		self.alpha = config['alpha']
		self.beta = config['beta']
		self.gamma = config['gamma']

		print("✓ Index loaded")


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("--mode", choices=["build", "search"], required=True)
	parser.add_argument("--data_path", help="movies_with_overview.csv")
	parser.add_argument("--index_path", default="movie_index.faiss")
	parser.add_argument("--metadata_path", default="movie_metadata.pkl")
	parser.add_argument("--query", help="Search query (for search mode)")
	parser.add_argument("--top_k", type=int, default=10)
	parser.add_argument("--alpha", type=float, default=0.7, help="语义权重")
	parser.add_argument("--beta", type=float, default=0.2, help="情感权重")
	parser.add_argument("--gamma", type=float, default=0.1, help="BM25权重")
	args = parser.parse_args()

	engine = MovieSearchEngine(
		alpha=args.alpha,
		beta=args.beta,
		gamma=args.gamma
	)

	if args.mode == "build":
		# 构建索引
		if not args.data_path:
			raise ValueError("--data_path required for build mode")

		df = pd.read_csv(args.data_path)
		engine.build_index(df)
		engine.save_index(args.index_path, args.metadata_path)

	else:
		# 搜索
		if not args.query:
			raise ValueError("--query required for search mode")

		engine.load_index(args.index_path, args.metadata_path)
		results = engine.search(args.query, top_k=args.top_k)

		print("\n=== Search Results ===")
		for item in results:
			print(f"\n#{item['rank']} {item['title']}")
			print(f"  Genres: {item['genres']}")
			print(f"  Overview: {item['overview']}")
			print(f"  Scores: Final={item['scores']['final']:.3f} | "
				  f"Semantic={item['scores']['semantic']:.3f} | "
				  f"Sentiment={item['scores']['sentiment']:.3f} | "
				  f"BM25={item['scores']['bm25']:.3f}")
			print(f"  Sentiment: Pos={item['sentiment']['positive']:.2f} | "
				  f"Neu={item['sentiment']['neutral']:.2f} | "
				  f"Neg={item['sentiment']['negative']:.2f}")


if __name__ == "__main__":
	main()