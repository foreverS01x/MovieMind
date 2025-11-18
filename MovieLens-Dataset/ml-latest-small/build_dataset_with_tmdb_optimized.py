#!/usr/bin/env python3
# -*- coding:utf-8 -*-

"""
优化版本：使用并发请求 + 自适应速率控制
预计时间：9742 部电影 → 约 10-15 分钟

Usage:
  python build_dataset_with_tmdb_optimized.py \
      --ml_movies_path movies.csv \
      --tmdb_api_key YOUR_API_KEY \
      --output movies_with_overview.csv \
      --workers 10
"""

import argparse
import pandas as pd
import requests
import time
import re
import json
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock

TMDB_SEARCH_URL = "https://api.themoviedb.org/3/search/movie"


class TMDbFetcher:
	def __init__(self, api_key: str, cache_path: str, max_workers: int = 10):
		self.api_key = api_key
		self.cache_path = cache_path
		self.max_workers = max_workers
		self.cache = self._load_cache()
		self.cache_lock = Lock()
		self.request_count = 0
		self.rate_limit_delay = 0.05  # 初始延迟 50ms

	def _load_cache(self):
		try:
			with open(self.cache_path, "r", encoding="utf-8") as f:
				return json.load(f)
		except:
			return {}

	def save_cache(self):
		with open(self.cache_path, "w", encoding="utf-8") as f:
			json.dump(self.cache, f, ensure_ascii=False, indent=2)

	def extract_year(self, title: str):
		match = re.search(r'\((\d{4})\)$', title)
		return int(match.group(1)) if match else None

	def tmdb_search(self, title: str, year: int, retry_count: int = 0):
		params = {
			"api_key": self.api_key,
			"query": title,
			"include_adult": False,
		}
		if year:
			params["year"] = year

		try:
			time.sleep(self.rate_limit_delay)  # 动态延迟
			resp = requests.get(TMDB_SEARCH_URL, params=params, timeout=10)

			if resp.status_code == 429:
				# 遇到限流，增加延迟
				self.rate_limit_delay = min(self.rate_limit_delay * 2, 2.0)
				if retry_count < 3:
					time.sleep(2)
					return self.tmdb_search(title, year, retry_count + 1)
				return []

			# 成功请求，逐渐降低延迟
			self.rate_limit_delay = max(self.rate_limit_delay * 0.95, 0.03)

			data = resp.json()
			return data.get("results", [])
		except Exception as e:
			if retry_count < 2:
				time.sleep(1)
				return self.tmdb_search(title, year, retry_count + 1)
			return []

	def pick_best_result(self, results, year):
		if not results:
			return None
		if year:
			filtered = [r for r in results if r.get("release_date", "").startswith(str(year))]
			if filtered:
				results = filtered
		results = sorted(results, key=lambda x: x.get("vote_count", 0), reverse=True)
		return results[0]

	def fetch_movie(self, title: str):
		# 检查缓存
		with self.cache_lock:
			if title in self.cache:
				return self.cache[title]["overview"], self.cache[title]["meta"]

		# 请求 TMDb
		year = self.extract_year(title)
		results = self.tmdb_search(title, year)
		best = self.pick_best_result(results, year)

		overview = best.get("overview", "") if best else ""
		meta = best

		# 写入缓存
		with self.cache_lock:
			self.cache[title] = {"overview": overview, "meta": meta}
			self.request_count += 1

			# 每 100 次请求保存一次缓存
			if self.request_count % 100 == 0:
				self.save_cache()

		return overview, meta

	def fetch_batch(self, titles: list):
		"""并发获取多个电影信息"""
		results = {}

		with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
			future_to_title = {
				executor.submit(self.fetch_movie, title): title
				for title in titles
			}

			with tqdm(total=len(titles), desc="Fetching TMDb data") as pbar:
				for future in as_completed(future_to_title):
					title = future_to_title[future]
					try:
						overview, meta = future.result()
						results[title] = {"overview": overview, "meta": meta}
					except Exception as e:
						print(f"\nError fetching {title}: {e}")
						results[title] = {"overview": "", "meta": None}
					pbar.update(1)

		return results


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("--ml_movies_path", required=True)
	parser.add_argument("--tmdb_api_key", required=True)
	parser.add_argument("--output", required=True)
	parser.add_argument("--cache", default="tmdb_cache.json")
	parser.add_argument("--workers", type=int, default=10,
						help="并发线程数（建议 5-15）")
	args = parser.parse_args()

	df = pd.read_csv(args.ml_movies_path)
	fetcher = TMDbFetcher(args.tmdb_api_key, args.cache, args.workers)

	print(f"Processing {len(df)} movies with {args.workers} workers...")
	start_time = time.time()

	# 并发获取所有电影信息
	titles = df["title"].tolist()
	results = fetcher.fetch_batch(titles)

	# 应用到 DataFrame
	df["overview"] = df["title"].map(lambda t: results[t]["overview"])
	df["tmdb_meta_raw"] = df["title"].map(lambda t: results[t]["meta"])

	# 保存结果
	df.to_csv(args.output, index=False)
	fetcher.save_cache()

	elapsed = time.time() - start_time
	print(f"\n✓ Completed in {elapsed / 60:.1f} minutes")
	print(f"✓ Saved to: {args.output}")
	print(f"✓ Cache saved to: {args.cache}")


if __name__ == "__main__":
	main()