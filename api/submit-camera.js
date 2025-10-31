/**
 * Vercel Serverless Function
 * Accepts anonymous camera submissions and creates GitHub issues
 */

module.exports = async function handler(req, res) {
  // Only accept POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // CORS headers (allow requests from your site)
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    const { title, labels, body } = req.body;

    // Validate required fields
    if (!title || !body || !labels) {
      return res.status(400).json({ 
        success: false,
        error: 'Missing required fields' 
      });
    }

    // Get GitHub credentials from environment variables
    const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
    const GITHUB_REPO = process.env.GITHUB_REPO || 'DukesR8/Camera-Database';

    if (!GITHUB_TOKEN) {
      console.error('GITHUB_TOKEN not configured');
      return res.status(500).json({ 
        success: false,
        error: 'Server configuration error - GitHub token not set' 
      });
    }

    // Create GitHub issue via API
    const githubResponse = await fetch(
      `https://api.github.com/repos/${GITHUB_REPO}/issues`,
      {
        method: 'POST',
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': `Bearer ${GITHUB_TOKEN}`,
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          title: title,
          body: body,
          labels: labels
        })
      }
    );

    if (!githubResponse.ok) {
      const errorData = await githubResponse.text();
      console.error('GitHub API error:', errorData);
      return res.status(githubResponse.status).json({ 
        success: false,
        error: 'Failed to create GitHub issue',
        details: errorData
      });
    }

    const issueData = await githubResponse.json();

    // Return success
    return res.status(200).json({
      success: true,
      issueNumber: issueData.number,
      issueUrl: issueData.html_url,
      message: 'Submission received! Issue #' + issueData.number + ' created.'
    });

  } catch (error) {
    console.error('Error processing submission:', error);
    return res.status(500).json({ 
      success: false,
      error: 'Internal server error',
      message: error.message 
    });
  }
};
