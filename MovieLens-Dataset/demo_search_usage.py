#!/usr/bin/env python3
# -*- coding:utf-8 -*-

"""
电影搜索系统使用示例

展示多种搜索场景：
1. 语义搜索
2. 情感偏好搜索
3. 混合搜索
"""

from movie_semantic_search import MovieSearchEngine
import pandas as pd


def demo_search():
	"""演示各种搜索场景"""

	# 初始化引擎（首次运行需要构建索引）
	engine = MovieSearchEngine(
		alpha=0.7,  # 语义相似度权重
		beta=0.2,  # 情感匹配权重
		gamma=0.1  # BM25 权重
	)

	# 方式1：从CSV构建索引（首次使用）
	print("=== Building Index (First Time Only) ===")
	df = pd.read_csv("movies_with_overview.csv")
	engine.build_index(df)
	engine.save_index("movie_index.faiss", "movie_metadata.pkl")

	# 方式2：加载已有索引（后续使用）
	# engine.load_index("movie_index.faiss", "movie_metadata.pkl")

	print("\n" + "=" * 80)
	print("DEMO: Movie Semantic Search System")
	print("=" * 80)

	# 场景1：抽象情感查询
	print("\n【场景1：抽象情感查询】")
	query1 = "一个关于友情的温馨的电影"
	results1 = engine.search(query1, top_k=5)
	print_results(results1)

	# 场景2：具体主题查询
	print("\n【场景2：具体主题查询】")
	query2 = "太空探险科幻电影"
	results2 = engine.search(query2, top_k=5)
	print_results(results2)

	# 场景3：情感偏好增强
	print("\n【场景3：情感偏好增强 - 寻找欢乐喜剧】")
	query3 = "轻松搞笑的喜剧"
	results3 = engine.search(
		query3,
		top_k=5,
		sentiment_boost={"positive": 1.5, "neutral": 0.0, "negative": -1.0}
	)
	print_results(results3)

	# 场景4：复杂查询
	print("\n【场景4：复杂多维度查询】")
	query4 = "一部发人深省的关于人性和道德困境的悬疑片"
	results4 = engine.search(query4, top_k=5)
	print_results(results4)

	# 场景5：英文查询
	print("\n【场景5：英文查询】")
	query5 = "heartwarming family animation"
	results5 = engine.search(query5, top_k=5)
	print_results(results5)


def print_results(results):
	"""格式化打印搜索结果"""
	for item in results:
		print(f"\n{'─' * 70}")
		print(f"#{item['rank']} 【{item['title']}】")
		print(f"类型: {item['genres']}")
		print(f"简介: {item['overview']}")
		print(f"\n评分详情:")
		print(f"  • 综合得分: {item['scores']['final']:.3f}")
		print(f"  • 语义相似度: {item['scores']['semantic']:.3f}")
		print(f"  • 情感匹配度: {item['scores']['sentiment']:.3f}")
		print(f"  • BM25得分: {item['scores']['bm25']:.3f}")
		print(f"\n情感分布:")
		print(f"  • 正面: {item['sentiment']['positive']:.1%}")
		print(f"  • 中性: {item['sentiment']['neutral']:.1%}")
		print(f"  • 负面: {item['sentiment']['negative']:.1%}")


def interactive_search():
	"""交互式搜索模式"""
	engine = MovieSearchEngine()

	# 加载索引
	try:
		engine.load_index("movie_index.faiss", "movie_metadata.pkl")
	except:
		print("索引不存在，正在构建...")
		df = pd.read_csv("movies_with_overview.csv")
		engine.build_index(df)
		engine.save_index("movie_index.faiss", "movie_metadata.pkl")

	print("\n" + "=" * 80)
	print("🎬 MovieMind - 智能电影搜索系统")
	print("=" * 80)
	print("\n输入查询开始搜索（输入 'quit' 退出）")
	print("示例: '一个关于友情的温馨的电影', '科幻冒险', 'romantic comedy'\n")

	while True:
		query = input("\n🔍 搜索: ").strip()

		if query.lower() in ['quit', 'exit', 'q', '退出']:
			print("再见！")
			break

		if not query:
			continue

		# 询问是否使用情感偏好
		use_sentiment = input("是否使用情感偏好？(y/n，默认n): ").strip().lower()

		sentiment_boost = None
		if use_sentiment == 'y':
			print("\n设置情感偏好（-1.0 到 1.0，正值表示偏好）:")
			pos = float(input("  正面情感: ") or "0")
			neu = float(input("  中性情感: ") or "0")
			neg = float(input("  负面情感: ") or "0")
			sentiment_boost = {"positive": pos, "neutral": neu, "negative": neg}

		# 搜索
		results = engine.search(query, top_k=10, sentiment_boost=sentiment_boost)

		# 显示结果
		print("\n" + "=" * 80)
		print(f"找到 {len(results)} 部相关电影:")
		print("=" * 80)
		print_results(results)


if __name__ == "__main__":
	import sys

	if len(sys.argv) > 1 and sys.argv[1] == "interactive":
		interactive_search()
	else:
		demo_search()