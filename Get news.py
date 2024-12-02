from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.action_chains import ActionChains
import time

def fetch_dynamic_content(url):
    # 设置 Chrome 驱动
    service = Service('/path/to/chromedriver')  # 替换为你的 ChromeDriver 路径
    options = webdriver.ChromeOptions()
    driver = webdriver.Chrome(service=service, options=options)

    try:
        driver.get(url)
        time.sleep(5)  # 等待动态内容加载

        # 查找“今日推荐”的内容
        elements = driver.find_elements(By.CSS_SELECTOR, 'div.ArticleList_articleList__3BrcS a')
        recommendations = []
        for elem in elements:
            title = elem.text
            link = elem.get_attribute('href')
            recommendations.append({'title': title, 'link': link})

        return recommendations
    finally:
        driver.quit()

# 示例使用
if __name__ == "__main__":
    url = "https://www.dxy.cn/"
    data = fetch_dynamic_content(url)
    if data:
        for idx, item in enumerate(data, start=1):
            print(f"{idx}. {item['title']}\n   链接: {item['link']}")
    else:
        print("未找到推荐内容。")
