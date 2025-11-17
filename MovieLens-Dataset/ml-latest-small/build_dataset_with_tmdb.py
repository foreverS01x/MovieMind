#!/usr/bin/env python3
# -*- coding:utf-8 -*-

"""
Usage:
  python build_dataset_with_tmdb.py \
      --ml_movies_path E:\github\MovieMind\MovieLens-Dataset\ml-latest-small\movies.csv \
      --links_path E:\github\MovieMind\MovieLens-Dataset\ml-latest-small\links.csv \
      --tmdb_api_key 9d5a5768705c19907badb63abbb20821 \
      --output E:\github\MovieMind\MovieLens-Dataset\ml-latest-small\movies_with_overview.csv
"""

import argparse
import pandas as pd
import requests
import time
import re
import json
import logging
from tqdm import tqdm

TMDB_SEARCH_URL = "https://api.themoviedb.org/3/search/movie"
TMDB_MOVIE_URL = "https://api.themoviedb.org/3/movie/{}"

def extract_year(title: str):
    """从 title 中提取年份，如 'Toy Story (1995)' → 1995"""
    match = re.search(r'\((\d{4})\)$', title)
    if match:
        return int(match.group(1))
    return None

def tmdb_get_movie_by_id(tmdb_id: int, api_key: str, session: requests.Session, max_retries: int = 5):
    """通过 TMDb ID 直接获取电影详情"""
    if pd.isna(tmdb_id) or tmdb_id == '' or tmdb_id == 0:
        logging.warning(f"Invalid TMDb ID: {tmdb_id}")
        return None
    
    url = TMDB_MOVIE_URL.format(int(tmdb_id))
    params = {"api_key": api_key}
    
    delay = 1
    for attempt in range(max_retries):
        try:
            resp = session.get(url, params=params, timeout=10)
        except Exception as e:
            logging.error(f"Request error for TMDb ID {tmdb_id}: {e}")
            time.sleep(delay)
            delay = min(delay * 2, 10)
            continue

        if resp.status_code == 429:
            retry_after = resp.headers.get("Retry-After")
            sleep_for = int(retry_after) if retry_after and retry_after.isdigit() else delay
            logging.warning(f"Rate limited for TMDb ID {tmdb_id}, sleeping {sleep_for}s")
            time.sleep(max(sleep_for, 1))
            delay = min(delay * 2, 10)
            continue
        
        if resp.status_code == 404:
            logging.warning(f"Movie not found for TMDb ID {tmdb_id}")
            return None

        if resp.ok:
            data = resp.json()
            logging.info(f"Successfully fetched data for TMDb ID {tmdb_id}: {data.get('title', 'Unknown')}")
            return data

        logging.error(f"Request failed ({resp.status_code}) for TMDb ID {tmdb_id}")
        time.sleep(delay)
        delay = min(delay * 2, 10)

    logging.error(f"Failed to fetch data for TMDb ID {tmdb_id} after {max_retries} attempts")
    return None

def tmdb_search(title: str, year: int, api_key: str, session: requests.Session, max_retries: int = 5):
    """调用 TMDb 搜索接口，命中 429 时自适应退避（备用方法）"""
    params = {
        "api_key": api_key,
        "query": title,
        "include_adult": False,
    }
    if year:
        params["year"] = year

    delay = 1
    for attempt in range(max_retries):
        try:
            resp = session.get(TMDB_SEARCH_URL, params=params, timeout=10)
        except Exception as e:
            logging.error(f"Search request error for title '{title}': {e}")
            time.sleep(delay)
            delay = min(delay * 2, 10)
            continue

        if resp.status_code == 429:
            retry_after = resp.headers.get("Retry-After")
            sleep_for = int(retry_after) if retry_after and retry_after.isdigit() else delay
            logging.warning(f"Rate limited for search '{title}', sleeping {sleep_for}s")
            time.sleep(max(sleep_for, 1))
            delay = min(delay * 2, 10)
            continue

        if resp.ok:
            data = resp.json()
            results = data.get("results", [])
            logging.info(f"Search for '{title}' returned {len(results)} results")
            return results

        logging.error(f"Search request failed ({resp.status_code}) for title: {title}")
        time.sleep(delay)
        delay = min(delay * 2, 10)

    logging.error(f"Failed to search for '{title}' after {max_retries} attempts")
    return []

def pick_best_tmdb_result(results, year):
    """选最匹配的结果：优先匹配年份，再按 vote_count 排序"""
    if not results:
        return None
    if year:
        filtered = [r for r in results if r.get("release_date", "").startswith(str(year))]
        if filtered:
            results = filtered
    # sort by vote_count desc
    results = sorted(results, key=lambda x: x.get("vote_count", 0), reverse=True)
    return results[0]

def fetch_overview_for_movie(title: str, tmdb_id: int, api_key: str, session: requests.Session):
    """优先通过 TMDb ID 获取 overview，失败时回退到搜索"""
    # 优先使用 TMDb ID 直接获取
    if tmdb_id and not pd.isna(tmdb_id) and tmdb_id != '' and tmdb_id != 0:
        movie_data = tmdb_get_movie_by_id(tmdb_id, api_key, session)
        if movie_data:
            overview = movie_data.get("overview", "")
            if overview:
                logging.info(f"Got overview via TMDb ID {tmdb_id} for '{title}': {len(overview)} chars")
                return overview, movie_data
            else:
                logging.warning(f"TMDb ID {tmdb_id} for '{title}' has no overview")
                return "", movie_data
    
    # 回退到搜索方式
    logging.info(f"Falling back to search for '{title}' (TMDb ID: {tmdb_id})")
    year = extract_year(title)
    results = tmdb_search(title, year, api_key, session)
    best = pick_best_tmdb_result(results, year)
    if best:
        overview = best.get("overview", "")
        if overview:
            logging.info(f"Got overview via search for '{title}': {len(overview)} chars")
        else:
            logging.warning(f"Search result for '{title}' has no overview")
        return overview, best
    
    logging.warning(f"No results found for '{title}'")
    return "", None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ml_movies_path", required=True, help="MovieLens movies.csv 文件路径")
    parser.add_argument("--links_path", required=True, help="MovieLens links.csv 文件路径")
    parser.add_argument("--tmdb_api_key", required=True, help="TMDb API Key")
    parser.add_argument("--output", required=True, help="输出文件路径")
    parser.add_argument("--cache", default="tmdb_cache.json",
                        help="本地缓存，避免重复 TMDb 请求")
    parser.add_argument("--log_level", default="INFO", 
                        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
                        help="日志级别")
    args = parser.parse_args()
    
    # 设置日志
    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('tmdb_fetch.log', encoding='utf-8'),
            logging.StreamHandler()
        ]
    )
    
    logging.info("开始处理电影数据...")
    
    # 读取数据文件
    df_movies = pd.read_csv(args.ml_movies_path)
    df_links = pd.read_csv(args.links_path)
    
    logging.info(f"读取到 {len(df_movies)} 部电影，{len(df_links)} 个链接")
    
    # 合并数据
    df = df_movies.merge(df_links, on='movieId', how='left')
    logging.info(f"合并后共 {len(df)} 条记录")

    # 缓存避免重复查询
    cache = {}
    try:
        with open(args.cache, "r", encoding="utf-8") as f:
            cache = json.load(f)
        logging.info(f"加载缓存，已有 {len(cache)} 条记录")
    except Exception as e:
        logging.info(f"无法加载缓存文件: {e}")
        cache = {}

    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": "MovieMindDatasetBuilder/1.0 (+https://www.themoviedb.org/)"
        }
    )

    overviews = []
    tmdb_meta = []
    
    # 统计信息
    stats = {
        "total": len(df),
        "cached": 0,
        "fetched_by_id": 0,
        "fetched_by_search": 0,
        "no_overview": 0,
        "failed": 0
    }

    logging.info(f"开始处理 {len(df)} 部电影...")
    for _, row in tqdm(df.iterrows(), total=len(df), desc="处理电影"):
        title = row["title"]
        tmdb_id = row.get("tmdbId", None)
        
        # 使用 movieId 作为缓存键，更稳定
        cache_key = f"{row['movieId']}_{title}"

        if cache_key in cache:
            overviews.append(cache[cache_key]["overview"])
            tmdb_meta.append(cache[cache_key]["meta"])
            stats["cached"] += 1
            continue

        overview, meta = fetch_overview_for_movie(title, tmdb_id, args.tmdb_api_key, session)
        overviews.append(overview)
        tmdb_meta.append(meta)

        # 统计
        if overview:
            if tmdb_id and not pd.isna(tmdb_id) and tmdb_id != '' and tmdb_id != 0:
                stats["fetched_by_id"] += 1
            else:
                stats["fetched_by_search"] += 1
        else:
            if meta:
                stats["no_overview"] += 1
            else:
                stats["failed"] += 1

        # 写入缓存
        cache[cache_key] = {"overview": overview, "meta": meta}
        
        # 每100条记录保存一次缓存
        if len(cache) % 100 == 0:
            with open(args.cache, "w", encoding="utf-8") as f:
                json.dump(cache, f, ensure_ascii=False, indent=2)

    # 添加结果到数据框
    df["overview"] = overviews
    df["tmdb_meta_raw"] = tmdb_meta
    
    # 只保留原始的 movies.csv 列加上新增的列
    output_df = df_movies.copy()
    output_df["overview"] = overviews
    output_df["tmdb_meta_raw"] = tmdb_meta

    output_df.to_csv(args.output, index=False)
    with open(args.cache, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)

    # 输出统计信息
    logging.info("处理完成！统计信息:")
    logging.info(f"  总计: {stats['total']}")
    logging.info(f"  缓存命中: {stats['cached']}")
    logging.info(f"  通过ID获取: {stats['fetched_by_id']}")
    logging.info(f"  通过搜索获取: {stats['fetched_by_search']}")
    logging.info(f"  无overview: {stats['no_overview']}")
    logging.info(f"  获取失败: {stats['failed']}")
    
    success_rate = (stats['fetched_by_id'] + stats['fetched_by_search']) / (stats['total'] - stats['cached']) * 100 if stats['total'] > stats['cached'] else 0
    logging.info(f"  成功率: {success_rate:.1f}%")
    
    print(f"处理完成！保存到: {args.output}")
    print(f"成功获取overview: {stats['fetched_by_id'] + stats['fetched_by_search']} / {stats['total'] - stats['cached']} ({success_rate:.1f}%)")

if __name__ == "__main__":
    main()
