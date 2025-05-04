<div align="center">

# IOTA DeFiAI - Intelligent Decentralized Finance

(AI-powered DeFi solutions built on IOTA)

![IOTA DeFiAI Banner](frontend/public/thumbnail-dark.png)

IOTA DeFiAI is an open-source platform that enhances decentralized finance with AI-powered solutions for smarter lending, risk management, and investment strategies. By combining Suna's AI capabilities with IOTA's feeless blockchain and Move smart contracts, we create intelligent financial services that adapt to market conditions and user needs.

[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](./license)
[![Discord Follow](https://dcbadge.limes.pink/api/server/Py6pCBUUPw?style=flat)](https://discord.gg/Py6pCBUUPw)
[![Twitter Follow](https://img.shields.io/twitter/follow/kortixai)](https://x.com/kortixai)
[![GitHub Repo stars](https://img.shields.io/github/stars/kortix-ai/suna)](https://github.com/kortix-ai/suna)
</div>


## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Technical Architecture](#technical-architecture)
- [IOTA Integration](#iota-integration)
- [AI Capabilities](#ai-capabilities)
- [Project Architecture](#project-architecture)
  - [Backend API](#backend-api)
  - [Frontend](#frontend)
  - [Agent Docker](#agent-docker)
  - [Supabase Database](#supabase-database)
- [Run Locally / Self-Hosting](#run-locally--self-hosting)
  - [Requirements](#requirements)
  - [Prerequisites](#prerequisites)
  - [Installation Steps](#installation-steps)
- [Acknowledgements](#acknowledgements)
- [License](#license)

## Overview

IOTA DeFiAI brings artificial intelligence to decentralized finance on the IOTA blockchain. Our platform uses machine learning algorithms to analyze market trends, evaluate risks, and optimize investment strategies, all while leveraging IOTA's feeless, scalable infrastructure and Move smart contracts for secure financial operations.

## Key Features

- **Smart Lending**: AI-driven credit scoring and dynamic loan terms that adapt to market conditions and borrower behavior.
- **Risk Shield**: Predictive analytics for market volatility and automated risk mitigation strategies.
- **Portfolio Optimizer**: Automated investment strategies tailored to user preferences and risk tolerance.
- **Market Insights**: Real-time analysis of on-chain and off-chain data to inform financial decisions.
- **Protocol Guardian**: Automated security monitoring and threat detection for protocol safety.

## Technical Architecture

Our platform combines several cutting-edge technologies:

```
┌─────────────────────┐      ┌──────────────────────┐
│ Frontend (Next.js)  │◄────►│ Backend (FastAPI)    │
└──────────┬──────────┘      └──────────┬───────────┘
           │                             │
           ▼                             ▼
┌─────────────────────┐      ┌──────────────────────┐
│ Suna AI Agent       │◄────►│ ML Analytics Engine  │
└──────────┬──────────┘      └──────────┬───────────┘
           │                             │
           ▼                             ▼
┌─────────────────────────────────────────────────────┐
│                IOTA Blockchain                       │
├─────────────────────────────────────────────────────┤
│ Move Smart Contracts (Lending, Investment, Risk)     │
└─────────────────────────────────────────────────────┘
```

## Demo video

## IOTA Integration

IOTA DeFiAI takes full advantage of IOTA's unique features:

- **Feeless Transactions**: Eliminating gas costs makes micro-transactions viable for DeFi operations.
- **Scalability**: High throughput ensures the platform can handle numerous financial operations simultaneously.
- **Move Smart Contracts**: We leverage IOTA Rebased's layer 1 Move smart contracts for secure, efficient financial applications.
- **Interoperability**: Seamless integration with other blockchain networks for a comprehensive DeFi ecosystem.

## AI Capabilities

Our platform employs several advanced AI techniques:

- **Predictive Analytics**: Forecasting market trends and asset performance.
- **Natural Language Processing**: Analyzing market sentiment from news and social media.
- **Reinforcement Learning**: Optimizing trading and investment strategies over time.
- **Anomaly Detection**: Identifying unusual patterns that may indicate fraud or market manipulation.
- **Personalized Recommendations**: Tailoring financial advice based on user profile and goals.

## Project Architecture

![Architecture Diagram](docs/images/diagram.png)

IOTA DeFiAI consists of four main components:

### Backend API
Python/FastAPI service that handles REST endpoints, thread management, and LLM integration with Anthropic, and others via LiteLLM.

### Frontend
Next.js/React application providing a responsive UI with chat interface, dashboard, etc.

### Agent Docker
Isolated execution environment for every agent - with browser automation, code interpreter, file system access, tool integration, and security features.

### Supabase Database
Handles data persistence with authentication, user management, conversation history, file storage, agent state, analytics, and real-time subscriptions.

## Run Locally / Self-Hosting

IOTA DeFiAI can be self-hosted on your own infrastructure. Follow these steps to set up your own instance.

### Requirements

You'll need the following components:
- A Supabase project for database and authentication
- Redis database for caching and session management
- Daytona sandbox for secure agent execution
- Python 3.11 for the API backend
- API keys for LLM providers (Anthropic)
- Tavily API key for enhanced search capabilities
- Firecrawl API key for web scraping capabilities
- Access to IOTA Testnet or Mainnet

### Prerequisites

1. **Supabase**:
   - Create a new [Supabase project](https://supabase.com/dashboard/projects)
   - Save your project's API URL, anon key, and service role key for later use
   - Install the [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started)

2. **Redis**: Set up a Redis instance using one of these options:
   - [Upstash Redis](https://upstash.com/) (recommended for cloud deployments)
   - Local installation:
     - [Mac](https://formulae.brew.sh/formula/redis): `brew install redis`
     - [Linux](https://redis.io/docs/getting-started/installation/install-redis-on-linux/): Follow distribution-specific instructions
     - [Windows](https://redis.io/docs/getting-started/installation/install-redis-on-windows/): Use WSL2 or Docker
   - Docker Compose (included in our setup):
     - If you're using our Docker Compose setup, Redis is included and configured automatically
     - No additional installation is needed
   - Save your Redis connection details for later use (not needed if using Docker Compose)

3. **Daytona**:
   - Create an account on [Daytona](https://app.daytona.io/)
   - Generate an API key from your account settings
   - Go to [Images](https://app.daytona.io/dashboard/images)
   - Click "Add Image"
   - Enter `adamcohenhillel/kortix-suna:0.0.20` as the image name
   - Set `/usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf` as the Entrypoint

4. **LLM API Keys**:
   - Obtain an API key [Anthropic](https://www.anthropic.com/)
   - While other providers should work via [LiteLLM](https://github.com/BerriAI/litellm), Anthropic is recommended – the prompt needs to be adjusted for other providers to output correct XML for tool calls.

5. **Search API Key** (Optional):
   - For enhanced search capabilities, obtain an [Tavily API key](https://tavily.com/)
   - For web scraping capabilities, obtain a [Firecrawl API key](https://firecrawl.dev/)

6. **IOTA Setup**:
   - Install the [IOTA TypeScript SDK](https://docs.iota.org/ts-sdk/typescript/)
   - Set up an IOTA Testnet or Mainnet connection
   - Install Move development tools for IOTA smart contracts

### Installation Steps

1. **Clone the repository**:
```bash
git clone https://github.com/kortix-ai/suna.git
cd suna
```

2. **Configure backend environment**:
```bash
cd backend
cp .env.example .env  # Create from example if available, or use the following template
```

Edit the `.env` file and fill in your credentials:
```bash
NEXT_PUBLIC_URL="http://localhost:3000"

# Supabase credentials from step 1
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# Redis credentials from step 2
REDIS_HOST=your_redis_host
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password
REDIS_SSL=True  # Set to False for local Redis without SSL

# Daytona credentials from step 3
DAYTONA_API_KEY=your_daytona_api_key
DAYTONA_SERVER_URL="https://app.daytona.io/api"
DAYTONA_TARGET="us"

# Anthropic
ANTHROPIC_API_KEY=

# OpenAI API:
OPENAI_API_KEY=your_openai_api_key

# Optional but recommended
TAVILY_API_KEY=your_tavily_api_key  # For enhanced search capabilities
FIRECRAWL_API_KEY=your_firecrawl_api_key  # For web scraping capabilities
RAPID_API_KEY=

# IOTA configuration
IOTA_NODE_URL=https://api.testnet.iota.cafe  # Use testnet for development
IOTA_EXPLORER_URL=https://explorer.rebased.iota.org/?network=testnet
```

3. **Set up Supabase database**:
```bash
# Login to Supabase CLI
supabase login

# Link to your project (find your project reference in the Supabase dashboard)
supabase link --project-ref your_project_reference_id

# Push database migrations
supabase db push
```

Then, go to the Supabase web platform again -> choose your project -> Project Settings -> Data API -> And in the "Exposed Schema" add "basejump" if not already there

4. **Configure frontend environment**:
```bash
cd ../frontend
cp .env.example .env.local  # Create from example if available, or use the following template
```

   Edit the `.env.local` file:
```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
NEXT_PUBLIC_BACKEND_URL="http://localhost:8000/api"  # Use this for local development
NEXT_PUBLIC_URL="http://localhost:3000"
NEXT_PUBLIC_IOTA_EXPLORER_URL=https://explorer.rebased.iota.org/?network=testnet
```

5. **Install IOTA SDK**:
```bash
# Install IOTA TypeScript SDK in the frontend
cd frontend
npm install @iota/iota-sdk
```

6. **Start the application**:

   In one terminal, start the frontend:
```bash
cd frontend
npm run dev
```

   In another terminal, start the backend:
```bash
cd backend
python api.py
```

7. **Access IOTA DeFiAI**:
   - Open your browser and navigate to `http://localhost:3000`
   - Sign up for an account using the Supabase authentication
   - Start exploring intelligent decentralized finance on IOTA!

## Acknowledgements

### Main Contributors
- [Adam Cohen Hillel](https://x.com/adamcohenhillel)
- [Dat-lequoc](https://x.com/datlqqq)
- [Marko Kraemer](https://twitter.com/markokraemer)

### Technologies
- [IOTA](https://www.iota.org/) - Feeless, scalable blockchain
- [Move](https://docs.iota.org/developer/iota-101/move-overview/) - Smart contract language for IOTA Rebased
- [Daytona](https://daytona.io/) - Secure agent execution environment
- [Supabase](https://supabase.com/) - Database and authentication
- [Playwright](https://playwright.dev/) - Browser automation
- [Anthropic](https://www.anthropic.com/) - LLM provider

## License

IOTA DeFiAI is licensed under the Apache License, Version 2.0. See [LICENSE](./LICENSE) for the full license text.

